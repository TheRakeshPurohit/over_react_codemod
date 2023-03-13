// Copyright 2023 Workiva Inc.
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

import 'constants.dart';

/// Suggestor that updates the [existingScriptPath] <script> line to [newScriptPath] and adds `type="module"` attribute to the script tag.
///
/// Meant to be run on HTML files (use [DartScriptUpdater] to run on Dart files).
class HtmlScriptUpdater {
  final String existingScriptPath;
  final String newScriptPath;

  // todo make sure the suggestor updates both prod and dev script lines

  HtmlScriptUpdater(this.existingScriptPath, this.newScriptPath);

  Stream<Patch> call(FileContext context) async* {
    // Do not update if the existingScriptPath isn't in the file.
    if (!context.sourceText.contains(existingScriptPath)) return;

    final scriptMatches = existingScriptPath.allMatches(context.sourceText);

    final patches = <Patch>[];

    scriptMatches.forEach((match) async {
      patches.add(Patch(
        newScriptPath,
        match.start,
        match.end,
      ));
    });

    yield* Stream.fromIterable(patches);

    // if (scriptMatches.isNotEmpty) {
    //   final lastMatch = scriptMatches.last;
    //
    //   // Only add [scriptToAdd] if it has the same prod/dev status as the
    //   // react-dart js [lastMatch] found.
    //   final lastMatchValue = lastMatch.group(0)!;
    //   if (isProd != isScriptProd(lastMatchValue)) return;
    //
    //   yield Patch(
    //     // Add the new script with the same indentation as the line before it.
    //     '\n${lastMatch.precedingWhitespaceGroup}'
    //     '${existingScriptPath.scriptTag(pathPrefix: lastMatch.pathPrefixGroup)}',
    //     lastMatch.end,
    //     lastMatch.end,
    //   );
    // }
  }
}
