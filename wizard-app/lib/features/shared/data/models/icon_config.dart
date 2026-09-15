// ignore_for_file: non_const_argument_for_const_parameter
import 'package:appwizard/core/utils/icon_resolver.dart';
import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

part 'icon_config.g.dart';

/// Model for serializable icon configuration.
/// Supports both legacy icon names and explicit IconData properties.
@JsonSerializable(explicitToJson: true)
class IconConfig {
  @JsonKey(fromJson: _iconDataFromJson, toJson: _iconDataToJson)
  final IconData? iconData;
  final bool isFontAwesome;

  IconConfig({
    this.iconData,
    this.isFontAwesome = false,
  });

  /// Factory constructor for JSON deserialization.
  /// Handles legacy String name and new property Map.
  factory IconConfig.fromJson(dynamic json) {
    if (json == null) return IconConfig();
    
    final result = IconResolver.resolve(json);
    return IconConfig(
      iconData: result.icon,
      isFontAwesome: result.isFontAwesome,
    );
  }

  Map<String, dynamic> toJson() => _$IconConfigToJson(this);

  static IconData? _iconDataFromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    // Remote-configured icons cannot be const; release builds use --no-tree-shake-icons.
    return IconData(
      json['codePoint'] as int,
      fontFamily: json['fontFamily'] as String?,
      fontPackage: json['fontPackage'] as String?,
      matchTextDirection: json['matchTextDirection'] as bool? ?? false,
    );
  }

  static Map<String, dynamic>? _iconDataToJson(IconData? icon) {
    if (icon == null) return null;
    return {
      'codePoint': icon.codePoint,
      'fontFamily': icon.fontFamily,
      'fontPackage': icon.fontPackage,
      'matchTextDirection': icon.matchTextDirection,
    };
  }


  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IconConfig &&
          runtimeType == other.runtimeType &&
          iconData == other.iconData &&
          isFontAwesome == other.isFontAwesome;

  @override
  int get hashCode => iconData.hashCode ^ isFontAwesome.hashCode;
}
