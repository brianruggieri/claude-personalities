import re


def validate_email(email):
    if not isinstance(email, str):
        raise TypeError("email must be a string")
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return bool(re.match(pattern, email))


def validate_password(password, min_length=8):
    if not isinstance(password, str):
        raise TypeError("password must be a string")
    if len(password) < min_length:
        return False, "too short"
    if not re.search(r'[A-Z]', password):
        return False, "missing uppercase"
    if not re.search(r'[a-z]', password):
        return False, "missing lowercase"
    if not re.search(r'[0-9]', password):
        return False, "missing digit"
    return True, "ok"


def validate_username(username):
    if not isinstance(username, str):
        raise TypeError("username must be a string")
    if len(username) < 3 or len(username) > 20:
        return False
    return bool(re.match(r'^[a-zA-Z][a-zA-Z0-9_]*$', username))
