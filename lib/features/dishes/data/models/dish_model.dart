import 'package:json_annotation/json_annotation.dart';

part 'dish_model.g.dart';

enum DishStatus {
  ok,
  deviation,
  overrun,
  draft,
}

@JsonSerializable(fieldRename: FieldRename.snake)
class DishModel {
  const DishModel({
    required this.id,
    required this.name,
    this.price,
    this.costPerPortion,
    this.weight,
    this.isAvailable = true,
    this.isActive = true,
    this.imageUrl,
    this.categoryId,
  });

  final int id;
  final String name;
  final double? price;

  @JsonKey(name: 'cost_per_portion')
  final double? costPerPortion;
  final double? weight;

  @JsonKey(name: 'is_available')
  final bool isAvailable;

  @JsonKey(name: 'is_active')
  final bool isActive;

  @JsonKey(name: 'image_url')
  final String? imageUrl;

  @JsonKey(name: 'category_id')
  final int? categoryId;

  double? get foodCostPct {
    if (price == null || price! <= 0 || costPerPortion == null) {
      return null;
    }
    return costPerPortion! / price! * 100;
  }

  DishStatus get status {
    if (!isActive) {
      return DishStatus.draft;
    }
    if (!isAvailable) {
      return DishStatus.deviation;
    }
    return DishStatus.ok;
  }

  factory DishModel.fromJson(Map<String, dynamic> json) =>
      _$DishModelFromJson(json);

  Map<String, dynamic> toJson() => _$DishModelToJson(this);
}

@JsonSerializable()
class DishListResponse {
  const DishListResponse({
    this.items = const [],
    this.total = 0,
  });

  final List<DishModel> items;
  final int total;

  factory DishListResponse.fromJson(Map<String, dynamic> json) =>
      _$DishListResponseFromJson(json);

  Map<String, dynamic> toJson() => _$DishListResponseToJson(this);
}
