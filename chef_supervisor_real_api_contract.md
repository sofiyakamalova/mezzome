# Chef and Supervisor real API contract

Purpose: short frontend-facing contract for the real server routes. This is
based on actual Gin registrations and handlers, not on the broad Swagger page.

Checked sources:
- `cmd/server/main.go`
- `internal/http/routes/v2/role_compat.go`
- `internal/http/routes/v2/manual_roles.go`
- `internal/http/handlers/*.go`
- `internal/dto/*.go`
- spot checks via `go run ./cmd/openapi_tool path --spec docs/swagger.json ...`

Important: many useful `/api/v2/chef/...` and `/api/v2/supervisor/...` routes
are real but are registered through `RegisterRoleCompatRoutes`. They are not
fake routes, but Swagger can show generic schemas for them.

Do not use the old docx paths directly. The tables below map those names to the
real backend routes that exist in code.

## Auth and dev accounts

This backend uses OTP flow, not old PIN login.

Send OTP:

```http
POST /api/v2/public/otp/send
Content-Type: application/json

{
  "phone": "+79000000005"
}
```

Response:

```json
{
  "message": "OTP sent successfully",
  "phone": "+79000000005"
}
```

Verify OTP:

```http
POST /api/v2/public/otp/verify
Content-Type: application/json

{
  "phone": "+79000000005",
  "otp": "111111",
  "device_id": "dev-chef-web",
  "device_type": "web",
  "app_version": "dev"
}
```

Response:

```json
{
  "message": "OTP verified successfully",
  "accessToken": "...",
  "refreshToken": "...",
  "pin": "1005",
  "session_id": "..."
}
```

Use:

```http
Authorization: Bearer <accessToken>
```

Seed users:

| Role | Phone | PIN | User ID | Main route prefix |
|---|---:|---:|---:|---|
| supervisor | `+79000000003` | `1003` | `990103` | `/api/v2/supervisor` |
| chef | `+79000000005` | `1005` | `990105` | `/api/v2/chef` |
| prep cook | `+79000000006` | `1006` | `990106` | `/api/v2/prep-cook` |
| butcher | `+79000000007` | `1007` | `990107` | `/api/v2/butcher` |
| cook | `+79000000010` | `1010` | `990110` | `/api/v2/cook` |
| cook backup | `+79000000011` | `1011` | `990111` | `/api/v2/cook` |
| manager | `+79000000009` | `1009` | `990109` | `/api/v2/manager` |

Kitchen role names:
- `chef` is the chef/senior kitchen role.
- `cook` is the unified hot/cold line cook role.
- `prep_cook` and `butcher` remain separate preparation roles.

Useful seed IDs:

| Entity | ID |
|---|---:|
| restaurant | `990001` |
| hot kitchen | `990011` |
| cold kitchen | `990012` |
| butcher kitchen | `990013` |
| approved production plan | `991101` |
| conditional production plan | `994401` |
| production batch completed | `991121` |
| production batch in progress | `991122` |
| approved technical card | `992001` |
| pending technical card | `994001` |
| supervisor approval | `993822` |
| chef escalation | `994201` |
| gastro container | `991212` |
| warehouse | `993001` |

## Routes from docx that are wrong or outdated

### Chef docx replacements

| Docx route | Real route |
|---|---|
| `GET /api/v2/chef/meal-templates` | `GET /api/v2/chef/production-plan-templates` |
| `POST /api/v2/chef/meal-templates` | `POST /api/v2/chef/production-plan-templates` |
| `PATCH /api/v2/chef/meal-templates/{id}` | `PATCH /api/v2/chef/production-plan-templates/{id}` |
| `GET /api/v2/chef/tk` | `GET /api/v2/chef/technical-cards` |
| `POST /api/v2/chef/tk` | `POST /api/v2/chef/technical-cards` |
| `PATCH /api/v2/chef/tk/{id}` | `PATCH /api/v2/chef/technical-cards/{id}` |
| `POST /api/v2/chef/tk/{id}/submit-for-approval` | `POST /api/v2/chef/technical-cards/{id}/submit` |
| `GET /api/v2/chef/tk/{id}/diff` | `GET /api/v2/chef/technical-cards/{id}/history` |
| `GET /api/v2/chef/plans` | `GET /api/v2/chef/production-plans` |
| `POST /api/v2/chef/plans` | `POST /api/v2/chef/production-plans` |
| `POST /api/v2/chef/plans/{id}/submit` | `POST /api/v2/chef/production-plans/{id}/check-stock`, then supervisor approval route |
| `POST /api/v2/chef/plans/{id}/conditional-submit` | `POST /api/v2/supervisor/production-plans/{id}/conditional-approve` |
| `POST /api/v2/chef/plans/copy-from` | `POST /api/v2/chef/production-plans/copy` |
| `GET /api/v2/chef/plans/{id}/monitor` | `GET /api/v2/chef/production-plans/{id}` plus batch/task routes below |
| `POST /api/v2/chef/plans/{id}/meals/{meal_id}/add-recook` | use unified cook recook queue routes; Chef only sees escalations and batch state |
| `POST /api/v2/chef/plans/{id}/items/{item_id}/shift-time` | no persisted item time-window model exists |
| `POST /api/v2/chef/plans/{id}/meals/{meal_id}/shift-window` | use `GET /api/v2/chef/production-plans/grid` |
| `POST /api/v2/chef/plans/{id}/items/{item_id}/replace` | `PATCH /api/v2/chef/production-plan-items/{item_id}` |
| `POST /api/v2/chef/plans/{id}/items/{item_id}/reduce` | `PATCH /api/v2/chef/production-plan-items/{item_id}` |
| `POST /api/v2/chef/plans/{id}/items/{item_id}/remove` | replace plan items with `PATCH /api/v2/chef/production-plans/{id}` |
| `GET /api/v2/chef/stock` | use inventory/production-control routes listed below |
| `GET /api/v2/procurement/pending` | `GET /api/v2/supervisor/procurements` for supervisor flow |
| `GET /api/v2/chef/plans/{id}/escalations` | `GET /api/v2/chef/escalations`; filter by status only |
| `POST /api/v2/chef/escalations/{id}/respond` | no Chef response route; supervisor resolves with `POST /api/v2/supervisor/escalations/{id}/ack` |
| `POST /api/v2/chef/attention-flags` | no create route; read production-control alerts with `GET /api/v2/chef/ai-alerts` |
| `GET /api/v2/variance/batch/{batch_id}/breakdown` | real alias exists as `GET /api/v2/variance/batch/{id}/breakdown` and `/api/v2/variance/batches/{id}/breakdown` |
| `POST /api/v2/regulatory/generate-tk-card` | real route exists |

### Supervisor docx replacements

| Docx route | Real route |
|---|---|
| `GET /api/v2/supervisor/plans/current` | `GET /api/v2/supervisor/production-plans?date=YYYY-MM-DD` or `GET /api/v2/supervisor/production-plans/grid?...` |
| `GET /api/v2/supervisor/plans/{id}/decomposition` | `GET /api/v2/supervisor/production-plans/{id}/theoretical`, plus `/capacity` and `/compliance` |
| `GET /api/v2/supervisor/preparations/pending-approval` | `GET /api/v2/supervisor/preparations/pending` |
| `GET /api/v2/supervisor/loss-approvals` | `GET /api/v2/supervisor/approvals` |
| `POST /api/v2/supervisor/loss-approvals/{id}/approve` | `POST /api/v2/supervisor/approvals/{id}/approve` |
| `POST /api/v2/supervisor/loss-approvals/{id}/reject` | `POST /api/v2/supervisor/approvals/{id}/reject` |
| `GET /api/v2/supervisor/chef-escalations/pending` | `GET /api/v2/supervisor/escalations?status=open` |
| `POST /api/v2/supervisor/chef-escalations/{id}/ack` | `POST /api/v2/supervisor/escalations/{id}/ack` |
| `POST /api/v2/supervisor/chef-escalations/{id}/resolve` | same endpoint: `POST /api/v2/supervisor/escalations/{id}/ack` with `{ "resolution": "..." }` |
| `POST /api/v2/supervisor/escalations-to-chef` | no direct route; chef escalation creation requires `POST /api/v2/chef/production-batches/{id}/escalations` |
| `POST /api/v2/supervisor/returns/start-session` | no session route; return records persist per container |
| `GET /api/v2/supervisor/returns/expected-containers` | `GET /api/v2/supervisor/returns/pending` |
| `POST /api/v2/supervisor/returns/{container_id}/accept` | use `POST /api/v2/supervisor/returns/{container_id}/weight`, then `/finalize` |
| `POST /api/v2/supervisor/returns/end-session` | no session route; return records persist per container |
| `GET /api/v2/supervisor/balance/today` | `GET /api/v2/supervisor/final-balance?production_batch_id=...` |
| `GET /api/v2/supervisor/balance/meal/{meal_id}` | no meal route; current balance is per production batch |
| `POST /api/v2/supervisor/shifts/{id}/close` | `PATCH /api/v2/chef/kitchens/{kitchen_id}/shifts/{shift_id}/close` |

## Response envelope rules

There is no single envelope for all routes.

New production routes return DTO directly:

```json
{
  "id": 991101,
  "status": "approved"
}
```

Some old/service routes return named maps:

```json
{
  "items": [],
  "pagination": {
    "page": 1,
    "page_size": 20,
    "total": 0,
    "total_pages": 0
  }
}
```

Some action routes return success/message:

```json
{
  "success": true,
  "message": "..."
}
```

Errors usually use:

```json
{
  "error": "...",
  "code": "INVALID_REQUEST"
}
```

## Chef routes

Base: `/api/v2/chef`
Auth role: `chef`

### Chef kitchen and order queue

| Method | Route | Query/body | Real response |
|---|---|---|---|
| `GET` | `/kitchens/current` | none | `dto.KitchenResponse` |
| `GET` | `/kitchen` | none | same as `/kitchens/current` |
| `GET` | `/kitchen-items` | `status`, `kitchen_id`, `page`, `page_size` | `{ items: dto.KitchenItemResponse[], pagination }` |
| `GET` | `/queue` | required `kitchen_id`; optional `status`, `page`, `page_size` | `{ items, summary, kitchen_id, pagination }` |
| `GET` | `/orders/kitchen/{kitchen_id}` | optional `status`, `page`, `page_size` | `{ orders: dto.KitchenOrderResponse[], pagination }` or `{ orders, total }` |
| `PUT` | `/kitchen-items/{item_id}/status` | `{ "status": "cooking" }` or `{ "status": "ready" }` | `dto.KitchenStatusResponse` |
| `PUT` | `/kitchen-items/status` | `{ "items": [{ "item_id": 993311, "status": "ready" }] }` | `dto.BatchItemStatusUpdateResponse` |

Example:

```http
GET /api/v2/chef/queue?kitchen_id=990011&status=pending&page=1&page_size=20
Authorization: Bearer <chefToken>
```

Response shape:

```json
{
  "items": [
    {
      "id": 993332,
      "menu_item_id": 990301,
      "menu_item_name": "...",
      "quantity": 1,
      "status": "pending",
      "order_id": 993304,
      "table_id": 993221,
      "table_number": 10,
      "ingredients": []
    }
  ],
  "summary": {
    "total_orders": 1,
    "pending_orders": 1,
    "cooking_orders": 0,
    "ready_orders": 0,
    "average_wait_time": 0
  },
  "kitchen_id": "990011",
  "pagination": {
    "page": 1,
    "page_size": 20,
    "total": 1,
    "total_pages": 1
  }
}
```

### Chef shifts and kitchen operations

| Method | Route | Query/body | Real response |
|---|---|---|---|
| `GET` | `/kitchens/{kitchen_id}/shifts/current` | path `kitchen_id` | `{ "shift": dto.CookShiftResponse }` |
| `POST` | `/kitchens/{kitchen_id}/shifts` | `{ "started_at": "2026-06-05T09:00:00Z" }` or `{}` | `{ "shift": dto.CookShiftResponse }` |
| `PATCH` | `/kitchens/{kitchen_id}/shifts/{shift_id}/close` | `{ "ended_at": "...", "note": "..." }` | `{ "shift": dto.CookShiftResponse }` |
| `GET` | `/kitchens/{kitchen_id}/operations` | optional filters from handler | `dto.KitchenOperationListResponse` |

### Chef technical cards

| Method | Route | Body/query | Real response |
|---|---|---|---|
| `GET` | `/technical-cards` | `search`, `status`, `include_all_versions=true` | `dto.TechnicalCardListResponse` |
| `POST` | `/technical-cards` | `dto.CreateTechnicalCardRequest` | `dto.TechnicalCardResponse` |
| `GET` | `/technical-cards/{id}` | path id | `dto.TechnicalCardResponse` |
| `PATCH` | `/technical-cards/{id}` | `dto.UpdateTechnicalCardRequest` | `dto.TechnicalCardResponse` |
| `POST` | `/technical-cards/{id}/submit` | `{ "reason": "..." }` | `dto.TechnicalCardResponse` |
| `GET` | `/technical-cards/{id}/versions` | path id | `dto.TechnicalCardListResponse` |
| `GET` | `/technical-cards/{id}/history` | path id | `dto.TechnicalCardChangeHistoryListResponse` |
| `GET` | `/technical-cards/{id}/compliance` | path id | map/object compliance payload |
| `POST` | `/technical-cards/{id}/approve` | `{ "reason": "..." }` | `dto.TechnicalCardResponse` |
| `POST` | `/technical-cards/{id}/reject` | `{ "reason": "..." }` | `dto.TechnicalCardResponse` |
| `GET` | `/technical-cards/{id}/export.pdf` | path id | PDF response |
| `GET` | `/loss-references` | optional `ingredient_id`, `status` | `{ "loss_references": dto.LossReferenceResponse[], "total": number }` |
| `POST` | `/loss-references` | `dto.LossReferenceRequest` | `dto.LossReferenceResponse` |

Create technical card body:

```json
{
  "name": "DEV frontend TK",
  "category_id": 990201,
  "menu_item_id": 990302,
  "description": "Frontend test",
  "output_per_portion": 380,
  "output_unit": "gr",
  "base_portions": 100,
  "halal_required": true,
  "submit_for_approval": true,
  "approval_reason": "frontend test",
  "ingredients": [
    {
      "ingredient_id": 990401,
      "brutto": 8,
      "netto": 8,
      "loss_coefficient": 0.18,
      "loss_source": "MANUAL",
      "cut_type": "beef_cube",
      "override_reason": "frontend test"
    }
  ],
  "steps": [
    {
      "name": "Prep",
      "description": "Prepare",
      "kitchen_section": "prep",
      "duration_minutes": 15
    }
  ]
}
```

### Chef production planning

| Method | Route | Body/query | Real response |
|---|---|---|---|
| `GET` | `/production-plans` | `date`, `service_type`, `status`, `kitchen_id`, `page`, `page_size` | `dto.ProductionPlanListResponse` |
| `POST` | `/production-plans` | `dto.ProductionPlanCreateRequest` | `dto.ProductionPlanResponse` |
| `GET` | `/production-plans/grid` | required `service_type`; `week_start` or `date`; optional `kitchen_id` | `dto.ProductionPlanGridResponse` |
| `GET` | `/production-plans/{id}` | path id | `dto.ProductionPlanResponse` |
| `PATCH` | `/production-plans/{id}` | `dto.ProductionPlanUpdateRequest` | `dto.ProductionPlanResponse` |
| `POST` | `/production-plans/{id}/cancel` | empty body | `dto.ProductionPlanCancelResponse` |
| `POST` | `/production-plans/{id}/check-stock` | empty body | `dto.ProductionPlanStockCheckResponse` |
| `GET` | `/production-plans/{id}/compliance` | path id | `dto.ProductionPlanComplianceResponse` |
| `GET` | `/production-plans/{id}/theoretical` | path id | `dto.ProductionPlanTheoreticalResponse` |
| `GET` | `/production-plans/{id}/variance-report` | optional `include_loss=true` | `dto.ProductionPlanVarianceResponse` |
| `GET` | `/production-plans/{id}/variance-breakdown` | optional `include_loss=true` | `dto.ProductionPlanVarianceBreakdownResponse` |
| `GET` | `/production-plan-templates` | none | `dto.ProductionPlanTemplateListResponse` |
| `POST` | `/production-plan-templates` | `dto.ProductionPlanTemplateRequest` | `dto.ProductionPlanTemplateResponse` |
| `PATCH` | `/production-plan-templates/{id}` | `dto.ProductionPlanTemplateRequest` | `dto.ProductionPlanTemplateResponse` |
| `POST` | `/production-plan-templates/{id}/create-plan` | `{ "planned_date": "2026-06-06" }` plus optional overrides | `dto.ProductionPlanResponse` |
| `POST` | `/production-plans/copy` | `dto.ProductionPlanCopyRequest` | `dto.ProductionPlanResponse` |
| `POST` | `/production-plans/copy-last-week` | copy request body | `dto.ProductionPlanResponse` |

Create plan body:

```json
{
  "kitchen_id": 990011,
  "service_type": "lunch",
  "planned_date": "2026-06-06",
  "people_count": 120,
  "reserve_coefficient": 1.15,
  "notes": "frontend test",
  "items": [
    {
      "menu_item_id": 990301,
      "slot_key": "main_1",
      "slot_title": "MAIN 1",
      "sort_order": 1,
      "planned_portions": 120
    }
  ]
}
```

List response shape:

```json
{
  "plans": [
    {
      "id": 991101,
      "kitchen_id": 990011,
      "service_type": "lunch",
      "planned_date": "2026-06-05T00:00:00Z",
      "people_count": 0,
      "status": "approved",
      "available_actions": ["view_batches", "view_variance_report"],
      "total_portions": 160,
      "total_cost": 0
    }
  ],
  "pagination": {
    "page": 1,
    "page_size": 20,
    "total": 1,
    "total_pages": 1
  },
  "totals": {
    "total_portions": 160,
    "total_cost": 0
  }
}
```

### Chef production runtime

| Method | Route | Body/query | Real response |
|---|---|---|---|
| `GET` | `/production-tasks` | optional `kitchen_id`, `status` | `dto.ChefProductionTasksResponse` |
| `GET` | `/production-batches/active` | none | `dto.ChefActiveProductionBatchesResponse` |
| `GET` | `/production-batches/{id}` | path id | `dto.ProductionBatchDetailResponse` |
| `POST` | `/production-batches/{id}/start` | empty body | `dto.ProductionBatchStartResponse` |
| `POST` | `/production-batches/{id}/complete` | `{ "produced_portions": 100 }` | `dto.ProductionBatchCompleteResponse` |
| `POST` | `/production-batches/{id}/serve` | `{ "portions": 20 }` | `dto.ProductionBatchServeResponse` |
| `POST` | `/production-batches/{id}/leftover-decision` | `{ "decision": "return_to_stock", "notes": "..." }` | `dto.ProductionBatchLeftoverDecisionResponse` |
| `POST` | `/production-batches/{id}/close` | empty body | `dto.ProductionBatchCloseResponse` |
| `POST` | `/production-batches/{id}/losses` | `dto.CreateProductionLossRequest` | `dto.ProductionLossResponse` |
| `POST` | `/production-batches/{id}/escalations` | `{ "reason": "...", "suggested_action": "..." }` | `dto.ChefEscalationResponse` |
| `GET` | `/escalations` | optional `status` | `dto.ChefEscalationListResponse` |
| `GET` | `/gastro-containers` | optional filters | `dto.GastroContainerListResponse` |
| `GET` | `/gastro-containers/{id}` | path id | `dto.GastroContainerResponse` |
| `POST` | `/gastro-containers` | `dto.GastroContainerCreateRequest[]`/create payload | `dto.GastroContainerListResponse` |

Batch detail:

```http
GET /api/v2/chef/production-batches/991122
```

Response shape:

```json
{
  "batch_id": 991122,
  "plan_id": 991101,
  "plan_item_id": 991112,
  "menu_item_id": 990302,
  "menu_item_name": "...",
  "kitchen_id": 990011,
  "status": "in_progress",
  "available_actions": [],
  "kpis": {
    "planned_portions": 60,
    "produced_portions": 30,
    "served_portions": 0,
    "leftover_portions": 0,
    "progress_pct": 50
  },
  "pipeline": [],
  "ingredient_batches": [],
  "preparation_batches": []
}
```

### Chef production-control reads

These routes are registered under chef compat:

| Method | Route | Query | Real response |
|---|---|---|---|
| `GET` | `/team-activity` | optional filters | `dto.TeamActivityResponse` |
| `GET` | `/line-assignments` | optional filters | `dto.KitchenLineAssignmentListResponse` |
| `GET` | `/line-options` | none | `dto.KitchenLineListResponse` |
| `GET` | `/ingredient-takes` | optional filters | `dto.IngredientTakeListResponse` |
| `GET` | `/warehouse-issues` | `warehouse_id`, `kitchen_id`, `status` | `dto.WarehouseIssueListResponse` |
| `GET` | `/kitchen-receipts` | `warehouse_id`, `kitchen_id`, `status` | `dto.KitchenReceiptListResponse` |
| `GET` | `/yield-controls` | `kitchen_id`, `status` | `dto.YieldControlListResponse` |
| `GET` | `/hall-transfers` | `kitchen_id`, `status` | `dto.HallTransferListResponse` |
| `GET` | `/day-closes` | `kitchen_id`, `service_type` | `dto.ProductionDayCloseListResponse` |
| `POST` | `/day-closes` | `{ "service_date": "2026-06-05", "kitchen_id": 990011, "service_type": "lunch" }` | `dto.ProductionDayCloseResponse` |
| `GET` | `/ai-alerts` | `warehouse_id`, `kitchen_id`, `status` | `dto.AIAlertListResponse` |
| `POST` | `/ai-alerts/{id}/ack` | empty body | `dto.AIAlertResponse` |
| `GET` | `/events` | `warehouse_id`, `kitchen_id`, `source_type` | `dto.ProductionEventListResponse` |

## Supervisor routes

Base: `/api/v2/supervisor`
Auth role: `supervisor`

### Supervisor orders and menu

| Method | Route | Query/body | Real response |
|---|---|---|---|
| `GET` | `/orders` | `status`, `date`, `page`, `page_size` | `{ orders, pagination }` or `dto.OrderListResponse` |
| `PUT` | `/orders/{id}` | `dto.OrderUpdateRequest` | `dto.OrderUpdatedResponse` |
| `DELETE` | `/orders/{id}` | none | delete response |
| `GET` | `/menu` | none | menu payload from supervisor service |
| `POST` | `/menu/categories` | owner menu category create body | category response |
| `PUT` | `/menu/categories/{id}` | owner menu category update body | category response |
| `GET` | `/menu/categories/{id}` | path id | category response |
| `DELETE` | `/menu/categories/{id}` | path id | delete response |
| `POST` | `/menu/items` | owner menu item create body | item response |
| `PUT` | `/menu/items/{id}` | owner menu item update body | item response |
| `GET` | `/menu/items/{id}` | path id | item response |
| `DELETE` | `/menu/items/{id}` | path id | delete response |
| `GET` | `/menu/combos` | none | combo list |
| `POST` | `/menu/combos` | combo create body | combo response |
| `POST` | `/menu/combos/{combo_id}/components` | component body | component response |
| `DELETE` | `/menu/combos/components/{component_id}` | path id | `dto.BaseResponse` |

### Supervisor kitchen, inventory, preparations

| Method | Route | Body/query | Real response |
|---|---|---|---|
| `GET` | `/kitchens/{kitchen_id}/reports/current` | path kitchen | `{ "report": dto.KitchenReportResponse }` |
| `POST` | `/kitchens/{kitchen_id}/operations` | `dto.KitchenOperationRequest` | `{ "operation": dto.KitchenOperationResponse }` |
| `GET` | `/kitchens/{kitchen_id}/operations` | optional filters | `dto.KitchenOperationListResponse` |
| `POST` | `/kitchens/{kitchen_id}/operations/{operation_id}/approve` | `dto.ApproveRequestOperationRequest` | `{ "operation": ... }` |
| `POST` | `/kitchens/{kitchen_id}/operations/{operation_id}/reject` | `{ "reason": "..." }` | `{ "success": true, "message": "..." }` |
| `POST` | `/kitchens/{kitchen_id}/warehouse-transfer` | `dto.DirectTransferRequest` | transfer response |
| `PATCH` | `/kitchens/{kitchen_id}/reports/{report_id}/submit` | `{ "note": "..." }` | report response |
| `GET` | `/dangerous-operations` | optional filters | dangerous-operation list |
| `GET` | `/inventory/count/pending` | none | `dto.InventoryCountListResponse` |
| `GET` | `/inventory/count` | filters | `dto.InventoryCountListResponse` |
| `POST` | `/inventory/count` | `dto.InventoryCountCreateRequest` | `dto.InventoryCountResponse` |
| `POST` | `/inventory/batch-count` | `dto.BatchInventoryCountCreateRequest` | `dto.BatchInventoryCountResponse` |
| `POST` | `/inventory/count/{id}/complete` | `dto.InventoryCountCompleteRequest` | `{ "success": true, "message": "..." }` |
| `GET` | `/preparations/pending` | none | `{ "preparations": [...] }` |
| `POST` | `/preparations/{id}/approve` | `dto.ApprovePreparationRequest` | `dto.PreparationProductionResponse` |
| `POST` | `/preparations/{id}/reject` | `dto.RejectPreparationRequest` | `dto.PreparationProductionResponse` |
| `POST` | `/warehouse/preparations/produce` | `dto.ProducePreparationRequest` | `dto.ProducePreparationResponse` |
| `POST` | `/warehouse/write-off` | `dto.WriteOffWarehouseRequest` | transaction response |
| `POST` | `/warehouse-transfer-between-warehouses` | transfer body | transfer response |

### Supervisor production plans and decisions

| Method | Route | Body/query | Real response |
|---|---|---|---|
| `GET` | `/production-plans` | `date`, `service_type`, `status`, `kitchen_id`, `page`, `page_size` | `dto.ProductionPlanListResponse` |
| `POST` | `/production-plans` | `dto.ProductionPlanCreateRequest` | `dto.ProductionPlanResponse` |
| `GET` | `/production-plans/grid` | required `service_type`; `week_start` or `date`; optional `kitchen_id` | `dto.ProductionPlanGridResponse` |
| `GET` | `/production-plans/{id}` | path id | `dto.ProductionPlanResponse` |
| `PATCH` | `/production-plans/{id}` | `dto.ProductionPlanUpdateRequest` | `dto.ProductionPlanResponse` |
| `POST` | `/production-plans/{id}/check-stock` | empty body | `dto.ProductionPlanStockCheckResponse` |
| `POST` | `/production-plans/{id}/approve` | `dto.ProductionPlanApproveRequest` | `dto.ProductionPlanApproveResponse` |
| `POST` | `/production-plans/{id}/conditional-approve` | `dto.ProductionPlanConditionalApproveRequest` | `dto.ProductionPlanConditionalApproveResponse` |
| `POST` | `/production-plans/{id}/reject` | `{ "reason": "..." }` | `dto.ProductionPlanResponse`/decision response |
| `POST` | `/production-plans/{id}/escalate-to-manager` | `{ "reason": "...", "severity": "high", "details": {} }` | escalation response |
| `POST` | `/production-plans/{id}/cancel` | empty body | `dto.ProductionPlanCancelResponse` |
| `GET` | `/production-plans/{id}/capacity` | path id | `dto.ProductionPlanCapacityResponse` |
| `GET` | `/production-plans/{id}/compliance` | path id | `dto.ProductionPlanComplianceResponse` |
| `GET` | `/production-plans/{id}/theoretical` | path id | `dto.ProductionPlanTheoreticalResponse` |
| `GET` | `/production-plans/{id}/variance-report` | optional `include_loss=true` | `dto.ProductionPlanVarianceResponse` |
| `GET` | `/production-plans/{id}/variance-breakdown` | optional `include_loss=true` | `dto.ProductionPlanVarianceBreakdownResponse` |
| `GET` | `/production-batches/{id}/losses` | path id | `dto.ProductionBatchLossListResponse` |

Approve body:

```json
{
  "force": false,
  "contract_id": 993101,
  "override_reason": "",
  "capacity_override_reason": ""
}
```

Approve response shape:

```json
{
  "plan_id": 991101,
  "status": "approved",
  "can_fulfill": true,
  "force_used": false,
  "compliance": {},
  "capacity": {},
  "shortages": [],
  "generated_prep_tasks": 0,
  "generated_ingredient_requests": 0,
  "approved_at": "2026-06-05T00:00:00Z",
  "approved_by": 990103
}
```

### Supervisor approvals, procurements, digest, traceability

| Method | Route | Body/query | Real response |
|---|---|---|---|
| `POST` | `/automations/sync` | empty body | `dto.SupervisorAutomationSyncResponse` |
| `GET` | `/approvals` | optional `status` | `dto.SupervisorApprovalListResponse` |
| `POST` | `/approvals/{id}/approve` | `{ "reason": "..." }` | `dto.SupervisorApprovalResponse` |
| `POST` | `/approvals/{id}/reject` | `{ "reason": "..." }` | `dto.SupervisorApprovalResponse` |
| `GET` | `/procurements` | optional `status` | `dto.PendingProcurementListResponse` |
| `POST` | `/procurements` | `dto.PendingProcurementCreateRequest` | `dto.PendingProcurementResponse` |
| `POST` | `/procurements/{id}/receive` | receive body from handler | `dto.PendingProcurementResponse` |
| `GET` | `/digest/weekly` | optional `week_start=YYYY-MM-DD` | `dto.SupervisorDigestResponse` |
| `GET` | `/traceability/batch/{batch_id}` | path batch id | `dto.SupervisorTraceabilityResponse` |
| `GET` | `/traceability/ingredient/{ingredient_id}` | path ingredient id | `dto.SupervisorTraceabilityResponse` |
| `GET` | `/escalations` | optional `status` | `dto.ChefEscalationListResponse` |
| `POST` | `/escalations/{id}/ack` | `{ "resolution": "..." }` | `dto.ChefEscalationResponse` |

Approvals list response:

```json
{
  "items": [
    {
      "id": 993822,
      "restaurant_id": 990001,
      "source_type": "preparation_production",
      "source_id": 991152,
      "category": "yield",
      "status": "pending",
      "severity": "critical",
      "reason": "DEV low yield approval",
      "details": {},
      "assigned_role": "supervisor",
      "requested_by": 990106,
      "requested_at": "2026-06-05T00:00:00Z",
      "due_at": "2026-06-05T00:00:00Z"
    }
  ],
  "total": 1
}
```

### Supervisor mass-control and returns

| Method | Route | Body/query | Real response |
|---|---|---|---|
| `POST` | `/warm-cabinets` | `dto.WarmCabinetCreateRequest` | `dto.WarmCabinetResponse` |
| `GET` | `/warm-cabinets` | none | `{ "items": [], "total": 0 }` |
| `GET` | `/gastro-containers` | filters | `dto.GastroContainerListResponse` |
| `GET` | `/review-queue` | none | `dto.ReviewQueueResponse` |
| `GET` | `/final-balance` | required `production_batch_id` | `dto.MassBalanceResponse` |
| `POST` | `/balance/close` | `dto.BalanceCloseRequest` | `dto.BalanceCloseResponse` |
| `GET` | `/returns/pending` | none | `dto.SupervisorReturnListResponse` |
| `POST` | `/returns/{container_id}/weight` | `dto.SupervisorReturnWeightRequest` | `dto.SupervisorReturnRecordResponse` |
| `POST` | `/returns/{container_id}/finalize` | `dto.SupervisorReturnFinalizeRequest` | `dto.SupervisorReturnRecordResponse` |
| `POST` | `/gastro-containers/{id}/unblock` | body/action request | `dto.GastroContainerResponse` |
| `POST` | `/gastro-containers/{id}/haccp-write-off` | action request | `dto.GastroContainerResponse` |
| `POST` | `/cabinets/{id}/unblock` | none/body optional | `{ "cabinet_id": ..., "unblocked_containers": ... }` |

Final balance:

```http
GET /api/v2/supervisor/final-balance?production_batch_id=991121
```

### Supervisor stock and batch expiry

| Method | Route | Body/query | Real response |
|---|---|---|---|
| `GET` | `/stock/analytics` | none | analytics object from supervisor service |
| `GET` | `/stock/mode` | none | `dto.StockModeResponse` |
| `PUT` | `/stock/mode` | `{ "mode": "strict" }` | `dto.StockModeResponse` |
| `GET` | `/stock/warnings` | none | `dto.StockWarningsResponse` |
| `GET` | `/batches/expiring` | optional `days` | expiring batches payload |
| `GET` | `/batches/expired` | none | expired batches payload |
| `POST` | `/batches/write-off-expired` | body from service | `dto.BaseResponse` |

### Supervisor technical cards

Supervisor has read-only TK routes:

| Method | Route | Real response |
|---|---|---|
| `GET` | `/technical-cards` | `dto.TechnicalCardListResponse` |
| `GET` | `/technical-cards/{id}` | `dto.TechnicalCardResponse` |
| `GET` | `/technical-cards/{id}/versions` | `dto.TechnicalCardListResponse` |
| `GET` | `/technical-cards/{id}/history` | `dto.TechnicalCardChangeHistoryListResponse` |
| `GET` | `/technical-cards/{id}/compliance` | compliance object |
| `GET` | `/loss-references` | `{ "loss_references": dto.LossReferenceResponse[], "total": number }` |

Approving TK and loss references is manager/owner flow, not supervisor flow.

## Shared traceability, variance, regulatory routes

These are authenticated for `chef`, `supervisor`, `manager`, `admin`, `owner`.

| Method | Route |
|---|---|
| `GET` | `/api/v2/traceability/search` |
| `GET` | `/api/v2/traceability/batches` |
| `GET` | `/api/v2/traceability/batch/{id}/timeline` |
| `GET` | `/api/v2/traceability/batch/{id}/parents` |
| `GET` | `/api/v2/traceability/batch/{id}/children` |
| `GET` | `/api/v2/traceability/batch/{id}/tree` |
| `GET` | `/api/v2/traceability/batch/{id}/balance` |
| `GET` | `/api/v2/traceability/batches/{id}/variance-breakdown` |
| `GET` | `/api/v2/variance/batch/{id}/breakdown` |
| `GET` | `/api/v2/variance/batches/{id}/breakdown` |
| `GET` | `/api/v2/variance/technical-cards/{id}/breakdown` |
| `GET` | `/api/v2/regulatory/templates` |
| `GET` | `/api/v2/regulatory/template/{id}` |
| `POST` | `/api/v2/regulatory/generate-tk-card` |
| `POST` | `/api/v2/regulatory/tk/generate` |
| `GET` | `/api/v2/regulatory/tk-cards/{id}` |

## Cook routes, not chef routes

For frontend screens named "cook", do not call `/api/v2/chef` unless the user
role is actually `chef`.

Cook and preparation roles:

| Prefix | Real DB role | Routes |
|---|---|---|
| `/api/v2/cook` | `cook` | queue/items/production-batches, recook requests, kitchen receipts, yield controls |
| `/api/v2/prep-cook` | `prep_cook` | preparation workflow, cutting samples, inventory |
| `/api/v2/butcher` | `butcher` | preparation workflow, butcher task workflow, inventory |

Recook routes are under the unified cook route:

```http
GET  /api/v2/cook/recook-requests?status=pending
POST /api/v2/cook/recook-requests/{id}/accept
POST /api/v2/cook/recook-requests/{id}/decline
```
