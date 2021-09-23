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
import 'package:over_react_codemod/src/util.dart';

/// Suggestor that adds a [scriptToAdd] line after the first usage of a
/// react-dart script in a file.
///
/// Meant to be run on HTML files (use [allHtmlPaths]).
class HtmlScriptAdder {
  final String scriptToAdd;

  HtmlScriptAdder(this.scriptToAdd);

  Stream<Patch> call(FileContext context) async* {
    // Do not add the script if it already exists in the file.
    if (context.sourceText.contains(scriptToAdd)) return;

    final reactScriptRegex =
        RegExp(r'([^\S\r\n]*)<script.*packages/react/react\w+.js.*</script>');
    final scriptMatch = reactScriptRegex.firstMatch(context.sourceText);

    if (scriptMatch != null) {
      yield Patch(
        // Add the new script with the same indentation as the line before it.
        '\n${scriptMatch.group(1)}$scriptToAdd',
        scriptMatch.end,
        scriptMatch.end,
      );
    }
  }
}
