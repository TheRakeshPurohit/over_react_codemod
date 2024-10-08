// Copyright 2024 Workiva Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Adapted from https://github.com/Workiva/over_react/blob/9079dff9405448ddaa5743a0ae408c4e0a056cec/tools/analyzer_plugin/lib/src/util/prop_declarations/get_all_props.dart

import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';

// Performance optimization notes:
// [2] Ideally we'd check the library and package here,
//     but for some reason accessing `.library` is pretty inefficient.
//     Possibly due to the `LibraryElementImpl? get library => thisOrAncestorOfType();` impl,
//     and an inefficient `thisOrAncestorOfType` impl: https://github.com/dart-lang/sdk/issues/53255

Iterable<InterfaceElement> getAllPropsClassesOrMixins(
    InterfaceElement propsElement) sync* {
  final propsAndSupertypeElements = propsElement.thisAndSupertypesList;

  // There are two UiProps; one in component_base, and one in builder_helpers that extends from it.
  // Use the component_base one, since there are some edge-cases of props that don't extend from the
  // builder_helpers version.
  final uiPropsElement = propsAndSupertypeElements.firstWhereOrNull((i) =>
      i.name == 'UiProps' &&
      i.library.name == 'over_react.component_declaration.component_base');

  // If propsElement does not inherit from from UiProps, it could still be a legacy mixin that doesn't implement UiProps.
  // This check is only necessary to retrieve props when [propsElement] is itself a legacy mixin, and not when legacy
  // props mixins are encountered below as supertypes.
  final inheritsFromUiProps = uiPropsElement != null;
  late final isPropsMixin = propsElement.metadata.any(_isPropsMixinAnnotation);
  if (!inheritsFromUiProps && !isPropsMixin) {
    return;
  }

  final uiPropsAndSupertypeElements = uiPropsElement?.thisAndSupertypesSet;

  for (final interface in propsAndSupertypeElements) {
    // Don't process UiProps or its supertypes
    // (Object, Map, MapBase, MapViewMixin, PropsMapViewMixin, ReactPropsMixin, UbiquitousDomPropsMixin, CssClassPropsMixin, ...)
    if (uiPropsAndSupertypeElements?.contains(interface) ?? false) continue;

    // Filter out generated accessors mixins for legacy concrete props classes.
    late final isFromGeneratedFile =
        interface.source.uri.path.endsWith('.over_react.g.dart');
    if (interface.name.endsWith('AccessorsMixin') && isFromGeneratedFile) {
      continue;
    }

    final isMixinBasedPropsMixin = interface is MixinElement &&
        interface.superclassConstraints.any((s) => s.element.name == 'UiProps');
    late final isLegacyPropsOrPropsMixinConsumerClass = !isFromGeneratedFile &&
        interface.metadata.any(_isOneOfThePropsAnnotations);

    if (!isMixinBasedPropsMixin && !isLegacyPropsOrPropsMixinConsumerClass) {
      continue;
    }

    yield interface;
  }
}

Iterable<FieldElement> getPropsDeclaredInMixin(
    InterfaceElement interface) sync* {
  for (final field in interface.fields) {
    if (field.isStatic) continue;
    if (field.isSynthetic) continue;

    final accessorAnnotation = _getAccessorAnnotation(field.metadata);
    final isNoGenerate = accessorAnnotation
            ?.computeConstantValue()
            ?.getField('doNotGenerate')
            ?.toBoolValue() ??
        false;
    if (isNoGenerate) continue;

    yield field;
  }
}

/// Returns all props defined in a props class/mixin [propsElement] as well as all of its supertypes,
/// except for those shared by all UiProps instances by default (e.g., ReactPropsMixin, UbiquitousDomPropsMixin,
/// and CssClassPropsMixin's key, ref, children, className, id, onClick, etc.).
///
/// Each returned field will be the consumer-declared prop field, and the list will not contain overrides
/// from generated over_react parts.
///
/// Excludes any fields annotated with `@doNotGenerate`.
Iterable<FieldElement> getAllProps(InterfaceElement propsElement) sync* {
  for (final interface in getAllPropsClassesOrMixins(propsElement)) {
    yield* getPropsDeclaredInMixin(interface);
  }
}

bool _isOneOfThePropsAnnotations(ElementAnnotation e) {
  // [2]
  final element = e.element;
  return element is ConstructorElement &&
      const {'Props', 'PropsMixin', 'AbstractProps'}
          .contains(element.enclosingElement.name);
}

bool _isPropsMixinAnnotation(ElementAnnotation e) {
  // [2]
  final element = e.element;
  return element is ConstructorElement &&
      element.enclosingElement.name == 'PropsMixin';
}

ElementAnnotation? _getAccessorAnnotation(List<ElementAnnotation> metadata) {
  return metadata.firstWhereOrNull((annotation) {
    // [2]
    final element = annotation.element;
    return element is ConstructorElement &&
        element.enclosingElement.name == 'Accessor';
  });
}

extension on InterfaceElement {
  // Two separate collection implementations to micro-optimize collection creation/iteration based on usage.

  Set<InterfaceElement> get thisAndSupertypesSet =>
      {this, for (final s in allSupertypes) s.element};

  List<InterfaceElement> get thisAndSupertypesList =>
      [this, for (final s in allSupertypes) s.element];
}
