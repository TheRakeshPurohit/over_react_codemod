from ..regexes import CLASS_DECLARATION_REGEX, WITH_PROPS_OR_STATE_MIXIN_REGEX
from ..updaters import update_props_or_state_mixin_usage
from .util import suggest_patches_from_pattern_sequence, suggest_patches_from_single_pattern


def with_props_and_state_mixins_suggestor(lines, _):
    # patterns = [
    #     CLASS_DECLARATION_REGEX,
    #     r'\s+with\s+',
    #     r'(.*(?:PropsMixin|StateMixin)[^\w])',
    #     r'\s*(?:implements|\{)',
    # ]

    # Rename props and state mixins
    for patch in suggest_patches_from_single_pattern(
            WITH_PROPS_OR_STATE_MIXIN_REGEX,
            lines,
            update_props_or_state_mixin_usage,
    ):
        yield patch
