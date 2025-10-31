class classproperty:
    """Turn a classmethod into a property of the class (and not of the instance). See below for usage:
    """

    def __init__(self, f):
        self.f = f

    def __get__(self, obj, owner):
        return self.f(owner)
