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

import 'package:codemod/codemod.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

class V3DependencyValidatorUpdater {
  String dependency;

  V3DependencyValidatorUpdater(this.dependency);

  Stream<Patch> call(FileContext context) async* {
    final config = YamlEditor(context.sourceText);
    const ignoreKey = 'ignore';

    final currentIgnoreList =
        config.parseAt([ignoreKey], orElse: () => YamlList()).value as YamlList;

    if (currentIgnoreList.isNotEmpty) {
      if (currentIgnoreList.contains(dependency)) return;

      config.update([ignoreKey], [...currentIgnoreList.toList(), dependency]);
      yield Patch(config.toString(), 0, context.sourceFile.length);
    } else {
      yield Patch('$ignoreKey:\n  - $dependency\n', context.sourceFile.length);
    }
  }
}
