import React, { useState, useEffect, useMemo, useCallback } from "react";

/* ─────────────────────────────────────────────────────────────
   MEZZOME · Технологическая карта повара (динамическая)
   Блюдо по умолчанию: Гуляш по-венгерски (OBED-GULYASH-VEN)
   Источник рецептуры: EUSS, исходная карта → Excel-техкарта
   Принцип: масса не врёт (брутто → нетто → выход → тарелка)
   ───────────────────────────────────────────────────────────── */

const C = {
  bg: "#0B0B0C",
  panel: "#141416",
  panel2: "#1B1B1E",
  line: "#2A2A2E",
  lime: "#D4FF3A",
  text: "#F4F4F2",
  dim: "#8A8A8F",
  dim2: "#5E5E63",
  amber: "#FFB020",
  red: "#FF5C5C",
  green: "#3DDC84",
};

const mono = "'IBM Plex Mono', ui-monospace, SFMono-Regular, monospace";
const sans = "'Manrope', system-ui, -apple-system, sans-serif";

// Нормативная рецептура на 1 порцию (из Excel-техкарты гуляша)
const BASE_RECIPE = [
  { sku: "MEAT-BEEF-01", name: "Говядина (мякоть)", brutto: 160, netto: 148, clean: 0.075, ugarka: 0.37, output: 93.2, price: 2800 },
  { sku: "VEG-LUK-01",   name: "Лук репчатый",      brutto: 60,  netto: 50,  clean: 0.1667, ugarka: 0.5,  output: 25,   price: 250 },
  { sku: "VEG-PEP-01",   name: "Перец сладкий",     brutto: 50,  netto: 40,  clean: 0.2,    ugarka: 0.38, output: 24.8, price: 900 },
  { sku: "VEG-POT-01",   name: "Картофель",         brutto: 80,  netto: 70,  clean: 0.125,  ugarka: 0.1,  output: 63,   price: 300 },
  { sku: "VEG-TOM-PST",  name: "Томатная паста",    brutto: 20,  netto: 20,  clean: 0,      ugarka: 0,    output: 20,   price: 1200 },
  { sku: "OIL-RAST-01",  name: "Масло растительное",brutto: 10,  netto: 10,  clean: 0,      ugarka: 0,    output: 10,   price: 900 },
  { sku: "SPC-PAP-01",   name: "Паприка молотая",   brutto: 2,   netto: 2,   clean: 0,      ugarka: 0,    output: 2,    price: 4500 },
  { sku: "VEG-CHE-01",   name: "Чеснок",            brutto: 5,   netto: 5,   clean: 0,      ugarka: 0.3,  output: 3.5,  price: 1500 },
];

const NORM_UGARKA = 0.30; // нормативная ужарка нетто→выход, %
const EQUIPMENT = ["Варочный котёл", "Пароконвектомат", "Плита", "Жарочная поверхность", "Сковорода", "Гриль", "Фритюр"];
const METHODS = ["Тушение", "Варка", "Жарка", "Запекание"];

const todayISO = () => new Date().toISOString().slice(0, 10);
const fmt = (n, d = 0) =>
  (isFinite(n) ? n : 0).toLocaleString("ru-RU", { minimumFractionDigits: d, maximumFractionDigits: d });
const pct = (n, d = 1) => `${fmt(n * 100, d)}%`;

const DEFAULT_PLAN = () => ({
  portions: 100,
  cookDate: todayISO(),
  method: "Тушение",
  equipment: ["Варочный котёл"],
  temp: 95,
  time: 90,
  humidity: 60,
  actualOutput: "",            // кг, факт взвешивания (повар вводит)
  liquidEnabled: false,
  liquidBrutto: 60,            // г/порция бульон/вода
  liquidUparka: 0.15,
  prices: Object.fromEntries(BASE_RECIPE.map((r) => [r.sku, r.price])),
  notes: "",
  log: [],
});

export default function MezzomeTechCard() {
  const [plan, setPlan] = useState(null);          // null = ещё грузим
  const [loadedDate, setLoadedDate] = useState(todayISO());
  const [savedAt, setSavedAt] = useState(null);
  const [dirty, setDirty] = useState(false);

  const storeKey = (d) => `mezzome:plan:gulyash:${d}`;

  // Загрузка плана на сегодня при открытии
  useEffect(() => {
    let cancelled = false;
    (async () => {
      const d = todayISO();
      let loaded = DEFAULT_PLAN();
      try {
        if (typeof window !== "undefined" && window.storage) {
          const res = await window.storage.get(storeKey(d));
          if (res && res.value) loaded = { ...DEFAULT_PLAN(), ...JSON.parse(res.value) };
        }
      } catch (e) {
        /* первого плана на сегодня ещё нет — стартуем с норматива */
      }
      if (!cancelled) { setPlan(loaded); setLoadedDate(d); }
    })();
    return () => { cancelled = true; };
  }, []);

  const upd = useCallback((patch) => {
    setPlan((p) => ({ ...p, ...patch }));
    setDirty(true);
  }, []);

  const save = useCallback(async () => {
    if (!plan) return;
    const stamp = new Date();
    const entry = { t: stamp.toISOString(), text: `План сохранён · ${plan.portions} порц.` };
    const next = { ...plan, log: [entry, ...(plan.log || [])].slice(0, 20) };
    try {
      if (typeof window !== "undefined" && window.storage) {
        await window.storage.set(storeKey(loadedDate), JSON.stringify(next));
      }
      setPlan(next);
      setSavedAt(stamp);
      setDirty(false);
    } catch (e) {
      setSavedAt(null);
    }
  }, [plan, loadedDate]);

  // ── Расчёты ─────────────────────────────────────────────
  const calc = useMemo(() => {
    if (!plan) return null;
    const N = Math.max(0, Number(plan.portions) || 0);
    const rows = BASE_RECIPE.map((r) => {
      const price = Number(plan.prices[r.sku]) || 0;
      const bruttoKg = (r.brutto * N) / 1000;
      const nettoKg = (r.netto * N) / 1000;
      const outKg = (r.output * N) / 1000;
      const sum = bruttoKg * price;
      return { ...r, price, bruttoKg, nettoKg, outKg, sum };
    });

    let bruttoKg = rows.reduce((a, r) => a + r.bruttoKg, 0);
    let nettoKg = rows.reduce((a, r) => a + r.nettoKg, 0);
    let outKg = rows.reduce((a, r) => a + r.outKg, 0);
    let cost = rows.reduce((a, r) => a + r.sum, 0);

    // Опциональный бульон/вода (Excel предупреждает: в карте нет жидкости)
    let liquid = null;
    if (plan.liquidEnabled) {
      const lb = (Number(plan.liquidBrutto) || 0) * N / 1000;
      const lo = lb * (1 - (Number(plan.liquidUparka) || 0));
      liquid = { bruttoKg: lb, nettoKg: lb, outKg: lo };
      bruttoKg += lb; nettoKg += lb; outKg += lo;
    }

    const plateG = N > 0 ? (outKg * 1000) / N : 0;        // г на тарелке (план)
    const cleanLoss = bruttoKg > 0 ? (bruttoKg - nettoKg) / bruttoKg : 0;
    const ugarka = nettoKg > 0 ? (nettoKg - outKg) / nettoKg : 0;
    const totalLoss = bruttoKg > 0 ? (bruttoKg - outKg) / bruttoKg : 0;
    const yieldPct = bruttoKg > 0 ? outKg / bruttoKg : 0;
    const costPerPortion = N > 0 ? cost / N : 0;
    const costPerKg = outKg > 0 ? cost / outKg : 0;

    // Факт vs норматив (масса не врёт)
    const actual = parseFloat(String(plan.actualOutput).replace(",", "."));
    let fact = null;
    if (isFinite(actual) && actual > 0) {
      const actUgarka = nettoKg > 0 ? (nettoKg - actual) / nettoKg : 0;
      const devPp = (actUgarka - NORM_UGARKA) * 100;       // отклонение в п.п.
      const deltaKg = actual - outKg;
      const actPlate = N > 0 ? (actual * 1000) / N : 0;
      let verdict = "ok", label = "Норма";
      if (Math.abs(devPp) > 6) { verdict = "bad"; label = "Расхождение"; }
      else if (Math.abs(devPp) > 3) { verdict = "warn"; label = "Проверить"; }
      fact = { actual, actUgarka, devPp, deltaKg, actPlate, verdict, label };
    }

    return { N, rows, liquid, bruttoKg, nettoKg, outKg, cost, plateG,
      cleanLoss, ugarka, totalLoss, yieldPct, costPerPortion, costPerKg, fact };
  }, [plan]);

  if (!plan || !calc) {
    return (
      <div style={{ ...wrap, display: "flex", alignItems: "center", justifyContent: "center", minHeight: "60vh" }}>
        <span style={{ color: C.dim, fontFamily: mono }}>Загружаю план на сегодня…</span>
      </div>
    );
  }

  const vColor = { ok: C.green, warn: C.amber, bad: C.red };

  return (
    <div style={wrap}>
      <style>{`@import url('https://fonts.googleapis.com/css2?family=Manrope:wght@400;500;600;700;800&family=IBM+Plex+Mono:wght@400;500;600&display=swap');
        * { box-sizing: border-box; }
        input, button, textarea { font-family: inherit; }
        input:focus, textarea:focus { outline: 1px solid ${C.lime}; outline-offset: -1px; }
        .mz-num::-webkit-outer-spin-button, .mz-num::-webkit-inner-spin-button { -webkit-appearance: none; margin: 0; }
        @media (max-width: 720px){ .mz-kpis{ grid-template-columns: repeat(2,1fr) !important; } .mz-cols{ grid-template-columns:1fr !important; } }
      `}</style>

      {/* ── Топбар ─────────────────────────────────────────── */}
      <header style={topbar}>
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          <div style={logoMark}>✕</div>
          <div style={{ fontWeight: 800, letterSpacing: 1, fontSize: 15 }}>MEZZOME</div>
          <span style={{ color: C.dim2, margin: "0 4px" }}>·</span>
          <span style={{ color: C.dim, fontSize: 13 }}>Технологическая карта</span>
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          {savedAt && !dirty && (
            <span style={{ color: C.green, fontSize: 12, fontFamily: mono }}>
              ✓ Сохранено {savedAt.toLocaleTimeString("ru-RU", { hour: "2-digit", minute: "2-digit" })}
            </span>
          )}
          <button onClick={save} style={{ ...btnPrimary, opacity: dirty || !savedAt ? 1 : 0.6 }}>
            Сохранить план
          </button>
        </div>
      </header>

      {/* ── Шапка блюда ────────────────────────────────────── */}
      <section style={{ ...panel, padding: 24 }}>
        <div style={{ display: "flex", justifyContent: "space-between", flexWrap: "wrap", gap: 16 }}>
          <div>
            <div style={statusPill}><span style={dot} /> Активна</div>
            <h1 style={{ margin: "14px 0 6px", fontSize: 30, fontWeight: 800, letterSpacing: -0.5 }}>
              Гуляш по-венгерски
            </h1>
            <div style={{ display: "flex", gap: 16, flexWrap: "wrap", color: C.dim, fontSize: 13, fontFamily: mono }}>
              <span>{`ID: OBED-GULYASH-VEN`}</span>
              <span style={chip}>обед</span>
              <span>Источник: EUSS</span>
            </div>
          </div>
        </div>

        {/* План на сегодня — сигнатурная полоса */}
        <div style={planStrip}>
          <div style={{ flex: "0 0 auto" }}>
            <div style={miniLabel}>Готовим на дату</div>
            <input type="date" value={plan.cookDate}
              onChange={(e) => upd({ cookDate: e.target.value })}
              style={{ ...inputDark, width: 160 }} />
          </div>

          <div style={{ flex: "0 0 auto" }}>
            <div style={miniLabel}>Порций на сегодня</div>
            <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
              <button style={stepBtn} onClick={() => upd({ portions: Math.max(0, plan.portions - 10) })}>−</button>
              <input className="mz-num" type="number" value={plan.portions}
                onChange={(e) => upd({ portions: Math.max(0, Number(e.target.value)) })}
                style={{ ...inputDark, width: 96, fontSize: 26, fontWeight: 700, textAlign: "center", color: C.lime }} />
              <button style={stepBtn} onClick={() => upd({ portions: plan.portions + 10 })}>+</button>
            </div>
          </div>

          <div style={{ flex: 1, minWidth: 180 }}>
            <div style={miniLabel}>Целевой выход · на тарелке</div>
            <div style={{ display: "flex", alignItems: "baseline", gap: 10 }}>
              <span style={{ fontFamily: mono, fontSize: 26, fontWeight: 600, color: C.text }}>
                {fmt(calc.outKg, 1)} <span style={{ fontSize: 14, color: C.dim }}>кг</span>
              </span>
              <span style={{ color: C.dim2 }}>·</span>
              <span style={{ fontFamily: mono, fontSize: 16, color: C.dim }}>{fmt(calc.plateG)} г/порция</span>
            </div>
          </div>
        </div>
      </section>

      {/* ── KPI ────────────────────────────────────────────── */}
      <div className="mz-kpis" style={kpiGrid}>
        <Kpi label="Себестоимость порции" value={`${fmt(calc.costPerPortion)} ₸`} accent />
        <Kpi label="Себестоимость 1 кг" value={`${fmt(calc.costPerKg)} ₸`} />
        <Kpi label="Сырьё на смену · брутто" value={`${fmt(calc.bruttoKg, 1)} кг`} />
        <Kpi label="Выход готового" value={pct(calc.yieldPct, 0)} />
      </div>

      <div className="mz-cols" style={{ display: "grid", gridTemplateColumns: "1.6fr 1fr", gap: 16, marginTop: 16 }}>
        {/* ── Левая колонка ─────────────────────────────── */}
        <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
          {/* Рецептура */}
          <section style={panel}>
            <div style={sectionHead}>
              <span>Рецептура</span>
              <span style={{ color: C.dim, fontFamily: mono, fontSize: 12 }}>× {calc.N} порц.</span>
            </div>
            <div style={{ overflowX: "auto" }}>
              <table style={table}>
                <thead>
                  <tr>
                    {["№", "Продукт", "Брутто, кг", "Нетто, кг", "Выход, кг", "Цена ₸/кг", "Сумма, ₸"].map((h, i) => (
                      <th key={h} style={{ ...th, textAlign: i >= 2 ? "right" : "left" }}>{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {calc.rows.map((r, i) => (
                    <tr key={r.sku} style={{ borderTop: `1px solid ${C.line}` }}>
                      <td style={{ ...td, color: C.dim2 }}>{i + 1}</td>
                      <td style={td}>
                        <div>{r.name}</div>
                        <div style={{ color: C.dim2, fontFamily: mono, fontSize: 11 }}>{r.sku}</div>
                      </td>
                      <td style={tdNum}>{fmt(r.bruttoKg, 1)}</td>
                      <td style={{ ...tdNum, color: C.dim }}>{fmt(r.nettoKg, 1)}</td>
                      <td style={{ ...tdNum, color: C.lime }}>{fmt(r.outKg, 1)}</td>
                      <td style={{ ...td, textAlign: "right", padding: "6px 4px" }}>
                        <input className="mz-num" type="number" value={r.price}
                          onChange={(e) => upd({ prices: { ...plan.prices, [r.sku]: Number(e.target.value) } })}
                          style={priceInput} />
                      </td>
                      <td style={{ ...tdNum, fontWeight: 600 }}>{fmt(r.sum)}</td>
                    </tr>
                  ))}
                  {plan.liquidEnabled && calc.liquid && (
                    <tr style={{ borderTop: `1px solid ${C.line}`, background: "rgba(212,255,58,0.04)" }}>
                      <td style={{ ...td, color: C.dim2 }}>+</td>
                      <td style={td}>Бульон / вода <span style={{ color: C.dim2, fontFamily: mono, fontSize: 11 }}>LIQ-01</span></td>
                      <td style={tdNum}>{fmt(calc.liquid.bruttoKg, 1)}</td>
                      <td style={{ ...tdNum, color: C.dim }}>{fmt(calc.liquid.nettoKg, 1)}</td>
                      <td style={{ ...tdNum, color: C.lime }}>{fmt(calc.liquid.outKg, 1)}</td>
                      <td style={{ ...td, textAlign: "right", color: C.dim2 }}>—</td>
                      <td style={{ ...tdNum, color: C.dim2 }}>0</td>
                    </tr>
                  )}
                  <tr style={{ borderTop: `2px solid ${C.line}` }}>
                    <td style={{ ...td, fontWeight: 700 }} colSpan={2}>ИТОГО</td>
                    <td style={{ ...tdNum, fontWeight: 700 }}>{fmt(calc.bruttoKg, 1)}</td>
                    <td style={{ ...tdNum, fontWeight: 700, color: C.dim }}>{fmt(calc.nettoKg, 1)}</td>
                    <td style={{ ...tdNum, fontWeight: 700, color: C.lime }}>{fmt(calc.outKg, 1)}</td>
                    <td style={td}></td>
                    <td style={{ ...tdNum, fontWeight: 800, color: C.lime }}>{fmt(calc.cost)}</td>
                  </tr>
                </tbody>
              </table>
            </div>

            <label style={liquidToggle}>
              <input type="checkbox" checked={plan.liquidEnabled}
                onChange={(e) => upd({ liquidEnabled: e.target.checked })}
                style={{ accentColor: C.lime, width: 16, height: 16 }} />
              <span>Добавить бульон / воду <span style={{ color: C.dim }}>— в исходной карте жидкость отсутствует, гуляш тушится с ней</span></span>
              {plan.liquidEnabled && (
                <span style={{ marginLeft: "auto", display: "flex", gap: 10, alignItems: "center" }}>
                  <span style={{ color: C.dim, fontSize: 12 }}>г/порц.</span>
                  <input className="mz-num" type="number" value={plan.liquidBrutto}
                    onChange={(e) => upd({ liquidBrutto: Number(e.target.value) })} style={{ ...priceInput, width: 64 }} />
                  <span style={{ color: C.dim, fontSize: 12 }}>упарка</span>
                  <input className="mz-num" type="number" value={Math.round(plan.liquidUparka * 100)}
                    onChange={(e) => upd({ liquidUparka: Number(e.target.value) / 100 })} style={{ ...priceInput, width: 52 }} />
                  <span style={{ color: C.dim, fontSize: 12 }}>%</span>
                </span>
              )}
            </label>
          </section>

          {/* Технология приготовления */}
          <section style={panel}>
            <div style={sectionHead}><span>Технология приготовления</span></div>
            <div style={{ padding: 16, display: "flex", flexDirection: "column", gap: 18 }}>
              <div>
                <div style={miniLabel}>Метод</div>
                <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
                  {METHODS.map((m) => (
                    <button key={m} onClick={() => upd({ method: m })}
                      style={selChip(plan.method === m)}>{m}</button>
                  ))}
                </div>
              </div>
              <div>
                <div style={miniLabel}>Оборудование</div>
                <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
                  {EQUIPMENT.map((eq) => {
                    const on = plan.equipment.includes(eq);
                    return (
                      <button key={eq}
                        onClick={() => upd({ equipment: on ? plan.equipment.filter((x) => x !== eq) : [...plan.equipment, eq] })}
                        style={selChip(on)}>{eq}</button>
                    );
                  })}
                </div>
              </div>
              <div style={{ display: "grid", gridTemplateColumns: "repeat(3,1fr)", gap: 12 }}>
                <Param label="Температура, °C" value={plan.temp} onChange={(v) => upd({ temp: v })} />
                <Param label="Время, мин" value={plan.time} onChange={(v) => upd({ time: v })} />
                <Param label="Влажность, %" value={plan.humidity} onChange={(v) => upd({ humidity: v })} />
              </div>
            </div>
          </section>
        </div>

        {/* ── Правая колонка ────────────────────────────── */}
        <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
          {/* Масса не врёт — зоны S0–S4 + факт */}
          <section style={panel}>
            <div style={sectionHead}>
              <span>Контроль процесса</span>
              <span style={{ color: C.dim2, fontFamily: mono, fontSize: 11 }}>масса не врёт</span>
            </div>
            <div style={{ padding: 16 }}>
              <Zone code="S0" name="Склад · списание (брутто)" plan={`${fmt(calc.bruttoKg, 1)} кг`} />
              <Zone code="S1" name="После чистки (нетто)" plan={`${fmt(calc.nettoKg, 1)} кг`} />
              <Zone code="S2–S3" name="Котёл · готовый выход" plan={`${fmt(calc.outKg, 1)} кг`}
                fact={calc.fact ? `${fmt(calc.fact.actual, 1)} кг` : null}
                factColor={calc.fact ? vColor[calc.fact.verdict] : null} last={false} />
              <Zone code="S4" name="Тарелка × порций" plan={`${fmt(calc.outKg, 1)} кг`} last />

              <div style={{ marginTop: 16, paddingTop: 16, borderTop: `1px solid ${C.line}` }}>
                <div style={miniLabel}>Факт. выход после т/о — взвесить котёл</div>
                <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
                  <input className="mz-num" type="number" placeholder="0.0" value={plan.actualOutput}
                    onChange={(e) => upd({ actualOutput: e.target.value })}
                    style={{ ...inputDark, width: 120, fontFamily: mono, fontSize: 18 }} />
                  <span style={{ color: C.dim }}>кг</span>
                  {calc.fact && (
                    <span style={{ ...verdictPill, color: vColor[calc.fact.verdict], borderColor: vColor[calc.fact.verdict] }}>
                      {calc.fact.label}
                    </span>
                  )}
                </div>
                {calc.fact && (
                  <div style={{ marginTop: 12, display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10, fontFamily: mono, fontSize: 12 }}>
                    <FactRow label="Факт. ужарка" value={pct(calc.fact.actUgarka)} />
                    <FactRow label="Норматив" value={pct(NORM_UGARKA, 0)} dim />
                    <FactRow label="Отклонение" value={`${calc.fact.devPp >= 0 ? "+" : ""}${fmt(calc.fact.devPp, 1)} п.п.`}
                      color={vColor[calc.fact.verdict]} />
                    <FactRow label="Δ масса" value={`${calc.fact.deltaKg >= 0 ? "+" : ""}${fmt(calc.fact.deltaKg, 1)} кг`}
                      color={vColor[calc.fact.verdict]} />
                  </div>
                )}
              </div>
            </div>
          </section>

          {/* Аналитика */}
          <section style={panel}>
            <div style={sectionHead}><span>Аналитика</span></div>
            <div style={{ padding: 16, display: "flex", flexDirection: "column", gap: 2 }}>
              <Ana label="Потери чистки (брутто→нетто)" value={pct(calc.cleanLoss)} />
              <Ana label="Ужарка / упарка (нетто→выход)" value={pct(calc.ugarka)} />
              <Ana label="Общие потери (брутто→тарелка)" value={pct(calc.totalLoss)} />
              <Ana label="Выход готовой продукции" value={pct(calc.yieldPct)} accent />
            </div>
          </section>

          {/* Заметки */}
          <section style={panel}>
            <div style={sectionHead}><span>Заметки шефа</span></div>
            <div style={{ padding: 16 }}>
              <textarea value={plan.notes} onChange={(e) => upd({ notes: e.target.value })}
                placeholder="Контрольное взвешивание, замены, замечания по партии…"
                style={textarea} rows={4} />
              {plan.log && plan.log.length > 0 && (
                <div style={{ marginTop: 12 }}>
                  {plan.log.map((l, i) => (
                    <div key={i} style={{ display: "flex", gap: 10, fontFamily: mono, fontSize: 11, color: C.dim, padding: "4px 0" }}>
                      <span style={{ color: C.dim2 }}>
                        {new Date(l.t).toLocaleString("ru-RU", { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" })}
                      </span>
                      <span>{l.text}</span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </section>
        </div>
      </div>

      <footer style={{ textAlign: "center", color: C.dim2, fontSize: 11, fontFamily: mono, padding: "20px 0 8px" }}>
        MEZZOME Kitchen OS · Технолог: __________ / дата · Повар: __________ / дата
      </footer>
    </div>
  );
}

/* ── Подкомпоненты ──────────────────────────────────────── */
function Kpi({ label, value, accent }) {
  return (
    <div style={{ ...panel, padding: "16px 18px" }}>
      <div style={miniLabel}>{label}</div>
      <div style={{ fontFamily: mono, fontSize: 24, fontWeight: 600, color: accent ? C.lime : C.text, letterSpacing: -0.5 }}>{value}</div>
    </div>
  );
}
function Param({ label, value, onChange }) {
  return (
    <div>
      <div style={miniLabel}>{label}</div>
      <input className="mz-num" type="number" value={value} onChange={(e) => onChange(Number(e.target.value))}
        style={{ ...inputDark, width: "100%", fontFamily: mono, fontSize: 18 }} />
    </div>
  );
}
function Zone({ code, name, plan, fact, factColor, last }) {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 12, padding: "10px 0", borderBottom: last ? "none" : `1px solid ${C.line}` }}>
      <div style={zoneCode}>{code}</div>
      <div style={{ flex: 1, fontSize: 13 }}>{name}</div>
      <div style={{ textAlign: "right" }}>
        <div style={{ fontFamily: mono, fontSize: 14, color: C.text }}>{plan}</div>
        {fact && <div style={{ fontFamily: mono, fontSize: 12, color: factColor }}>факт {fact}</div>}
      </div>
    </div>
  );
}
function FactRow({ label, value, color, dim }) {
  return (
    <div style={{ display: "flex", justifyContent: "space-between" }}>
      <span style={{ color: C.dim2 }}>{label}</span>
      <span style={{ color: color || (dim ? C.dim : C.text), fontWeight: 600 }}>{value}</span>
    </div>
  );
}
function Ana({ label, value, accent }) {
  return (
    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "9px 0", borderBottom: `1px solid ${C.line}` }}>
      <span style={{ fontSize: 13, color: C.dim }}>{label}</span>
      <span style={{ fontFamily: mono, fontSize: 16, fontWeight: 600, color: accent ? C.lime : C.text }}>{value}</span>
    </div>
  );
}

/* ── Стили ──────────────────────────────────────────────── */
const wrap = { background: C.bg, color: C.text, minHeight: "100vh", fontFamily: sans, padding: "20px clamp(12px,4vw,40px)", maxWidth: 1180, margin: "0 auto" };
const topbar = { display: "flex", justifyContent: "space-between", alignItems: "center", padding: "8px 0 20px" };
const logoMark = { width: 28, height: 28, borderRadius: 8, background: C.lime, color: C.bg, display: "grid", placeItems: "center", fontWeight: 900, fontSize: 14 };
const btnPrimary = { background: C.lime, color: C.bg, border: "none", borderRadius: 10, padding: "9px 16px", fontWeight: 700, fontSize: 13, cursor: "pointer" };
const panel = { background: C.panel, border: `1px solid ${C.line}`, borderRadius: 16 };
const statusPill = { display: "inline-flex", alignItems: "center", gap: 7, background: "rgba(61,220,132,0.12)", color: C.green, border: `1px solid rgba(61,220,132,0.3)`, borderRadius: 999, padding: "4px 12px", fontSize: 12, fontWeight: 600 };
const dot = { width: 7, height: 7, borderRadius: 99, background: C.green };
const chip = { background: C.panel2, border: `1px solid ${C.line}`, borderRadius: 6, padding: "1px 8px", color: C.dim, fontFamily: sans };
const planStrip = { marginTop: 22, display: "flex", gap: 24, flexWrap: "wrap", alignItems: "flex-end", background: C.panel2, border: `1px solid ${C.line}`, borderRadius: 14, padding: 18 };
const miniLabel = { color: C.dim, fontSize: 11, textTransform: "uppercase", letterSpacing: 0.8, marginBottom: 7, fontWeight: 600 };
const inputDark = { background: C.bg, border: `1px solid ${C.line}`, borderRadius: 10, color: C.text, padding: "9px 12px", fontSize: 14 };
const stepBtn = { width: 38, height: 44, borderRadius: 10, background: C.bg, border: `1px solid ${C.line}`, color: C.lime, fontSize: 20, cursor: "pointer", fontWeight: 600 };
const kpiGrid = { display: "grid", gridTemplateColumns: "repeat(4,1fr)", gap: 16, marginTop: 16 };
const sectionHead = { display: "flex", justifyContent: "space-between", alignItems: "center", padding: "14px 16px", borderBottom: `1px solid ${C.line}`, fontWeight: 700, fontSize: 14 };
const table = { width: "100%", borderCollapse: "collapse", fontSize: 13 };
const th = { padding: "10px 4px", color: C.dim, fontWeight: 600, fontSize: 11, textTransform: "uppercase", letterSpacing: 0.5 };
const td = { padding: "10px 4px", verticalAlign: "top" };
const tdNum = { padding: "10px 4px", textAlign: "right", fontFamily: mono, whiteSpace: "nowrap" };
const priceInput = { width: 72, background: C.bg, border: `1px solid ${C.line}`, borderRadius: 8, color: C.text, padding: "6px 8px", fontFamily: mono, fontSize: 13, textAlign: "right" };
const liquidToggle = { display: "flex", alignItems: "center", gap: 10, padding: "12px 16px", borderTop: `1px solid ${C.line}`, fontSize: 13, cursor: "pointer", color: C.text };
const selChip = (on) => ({ background: on ? C.lime : C.panel2, color: on ? C.bg : C.dim, border: `1px solid ${on ? C.lime : C.line}`, borderRadius: 999, padding: "7px 14px", fontSize: 13, fontWeight: 600, cursor: "pointer" });
const zoneCode = { fontFamily: mono, fontSize: 11, fontWeight: 600, color: C.lime, background: "rgba(212,255,58,0.1)", border: `1px solid rgba(212,255,58,0.25)`, borderRadius: 6, padding: "3px 7px", minWidth: 48, textAlign: "center" };
const verdictPill = { border: "1px solid", borderRadius: 999, padding: "4px 12px", fontSize: 12, fontWeight: 700, fontFamily: mono };
const textarea = { width: "100%", background: C.bg, border: `1px solid ${C.line}`, borderRadius: 10, color: C.text, padding: 12, fontSize: 13, resize: "vertical", lineHeight: 1.5 };
