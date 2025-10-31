from class_property import classproperty


class CONSTANT_MIXIN:
    @classproperty
    def ALL(cls):
        return [getattr(cls, attr) for attr in dir(cls()) if attr.isupper() and attr != 'ALL']


class STACK_TYPE(CONSTANT_MIXIN):
    MEDICAL_DEV = 'MEDICAL_DEV'
    MEDICAL_DEV_FACTU = 'MEDICAL_DEV_FACTU'
    MEDICAL_INTEGRATION = 'MEDICAL_INTEGRATION'
    STATS_ANONYMIZE = 'STATS_ANONYMIZE'
    STATS_NON_ANONYMIZE = 'STATS_NON_ANONYMIZE'

    @staticmethod
    def is_stats(stack_type: str) -> bool:
        return stack_type in (STACK_TYPE.STATS_NON_ANONYMIZE, STACK_TYPE.STATS_ANONYMIZE)

    @staticmethod
    def is_medical(stack_type: str) -> bool:
        return stack_type in (STACK_TYPE.MEDICAL_DEV, STACK_TYPE.MEDICAL_DEV_FACTU, STACK_TYPE.MEDICAL_INTEGRATION)


STACK_TYPE_TO_STACK_FOLDER = {
    STACK_TYPE.MEDICAL_DEV: "dev-stacks-ondemand",
    STACK_TYPE.MEDICAL_DEV_FACTU: "factu-stacks",
    STACK_TYPE.MEDICAL_INTEGRATION: "integration-stacks",
    STACK_TYPE.STATS_ANONYMIZE: "stats-anonymize-stacks",
    STACK_TYPE.STATS_NON_ANONYMIZE: "stats-non-anonymize-stacks",
}

DEV_APPS_REPO_DEFAULT_BRANCH = 'main'
STACK_NAME_MAX_LENGTH = 35
