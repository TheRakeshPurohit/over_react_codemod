// Copyright 2021 Workiva Inc.
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

import 'dart:js_util';

import 'package:over_react_codemod/src/unify_package_rename_suggestors/package_rename_component_usage_migrator.dart';
import 'package:test/test.dart';

import '../mui_suggestors/components/shared.dart';
import '../resolved_file_context.dart';
import '../util.dart';

void main() {
  final resolvedContext = SharedAnalysisContext.rmui;

  // Warm up analysis in a setUpAll so that if getting the resolved AST times out
  // (which is more common for the WSD context), it fails here instead of failing the first test.
  setUpAll(resolvedContext.warmUpAnalysis);

  group('PackageRenameComponentUsageMigrator', () {
    final testSuggestor = getSuggestorTester(
      PackageRenameComponentUsageMigrator(),
      resolvedContext: resolvedContext,
    );

    test(
        'abc', () async {
      await testSuggestor(
        input: /*language=dart*/ '''
    import 'package:over_react/over_react.dart';
    import 'package:react_material_ui/react_material_ui.dart' as mui;
    
    content() {
      mui.Button()();
    }
''',
      );
    });
  });
}
