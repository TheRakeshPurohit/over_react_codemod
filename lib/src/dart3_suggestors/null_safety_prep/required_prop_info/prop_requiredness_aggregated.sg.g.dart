// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: implicit_dynamic_parameter

part of 'prop_requiredness_aggregated.sg.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PropRequirednessResults _$PropRequirednessResultsFromJson(
        Map<String, dynamic> json) =>
    PropRequirednessResults(
      excludeOtherDynamicUsages: json['excludeOtherDynamicUsages'] as bool,
      excludeUsagesWithForwarded: json['excludeUsagesWithForwarded'] as bool,
      resultsByPropNameByMixinByPackage:
          (json['resultsByPropNameByMixinByPackage'] as Map<String, dynamic>)
              .map(
        (k, e) => MapEntry(
            k,
            (e as Map<String, dynamic>).map(
              (k, e) => MapEntry(
                  k,
                  (e as Map<String, dynamic>).map(
                    (k, e) => MapEntry(
                        k, PropResult.fromJson(e as Map<String, dynamic>)),
                  )),
            )),
      ),
      mixinMetadata:
          MixinMetadata.fromJson(json['mixinMetadata'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PropRequirednessResultsToJson(
        PropRequirednessResults instance) =>
    <String, dynamic>{
      'excludeOtherDynamicUsages': instance.excludeOtherDynamicUsages,
      'excludeUsagesWithForwarded': instance.excludeUsagesWithForwarded,
      'resultsByPropNameByMixinByPackage':
          instance.resultsByPropNameByMixinByPackage,
      'mixinMetadata': instance.mixinMetadata,
    };

MixinMetadata _$MixinMetadataFromJson(Map<String, dynamic> json) =>
    MixinMetadata(
      mixinNamesById: Map<String, String>.from(json['mixinNamesById'] as Map),
      mixinPackagesById:
          Map<String, String>.from(json['mixinPackagesById'] as Map),
    );

Map<String, dynamic> _$MixinMetadataToJson(MixinMetadata instance) =>
    <String, dynamic>{
      'mixinNamesById': instance.mixinNamesById,
      'mixinPackagesById': instance.mixinPackagesById,
    };

PropResult _$PropResultFromJson(Map<String, dynamic> json) => PropResult(
      samePackageRate: json['samePackageRate'] as num?,
      otherPackageRate: json['otherPackageRate'] as num?,
      totalRate: json['totalRate'] as num,
      samePackageUsageCount: json['samePackageUsageCount'] as int,
      otherPackageUsageCount: json['otherPackageUsageCount'] as int,
      totalUsageCount: json['totalUsageCount'] as int,
      debugSamePackageUnsetUsages:
          (json['debugSamePackageUnsetUsages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      debugOtherPackageUnsetUsages:
          (json['debugOtherPackageUnsetUsages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
    );

Map<String, dynamic> _$PropResultToJson(PropResult instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('samePackageRate', instance.samePackageRate);
  writeNotNull('otherPackageRate', instance.otherPackageRate);
  val['totalRate'] = instance.totalRate;
  val['samePackageUsageCount'] = instance.samePackageUsageCount;
  val['otherPackageUsageCount'] = instance.otherPackageUsageCount;
  val['totalUsageCount'] = instance.totalUsageCount;
  writeNotNull(
      'debugSamePackageUnsetUsages', instance.debugSamePackageUnsetUsages);
  writeNotNull(
      'debugOtherPackageUnsetUsages', instance.debugOtherPackageUnsetUsages);
  return val;
}
