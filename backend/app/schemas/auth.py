import re
from datetime import datetime
from enum import Enum
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator, model_validator


class UserRole(str, Enum):
    STUDENT = "student"
    TUTOR = "tutor"
    ADMIN = "admin"


class StudentGrade(str, Enum):
    G6 = "6"
    G7 = "7"
    G8 = "8"
    G9 = "9"
    OL = "O/L"
    AL = "A/L"


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


def validate_strong_password(password: str) -> str:
    if len(password) < 8:
        raise ValueError("Password must be at least 8 characters")
    if not re.search(r"[a-z]", password):
        raise ValueError("Password must contain a lowercase letter")
    if not re.search(r"[A-Z]", password):
        raise ValueError("Password must contain an uppercase letter")
    if not re.search(r"\d", password):
        raise ValueError("Password must contain a number")
    if not re.search(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;/]', password):
        raise ValueError("Password must contain a special character")
    return password


class UserRegister(BaseModel):
    name: str = Field(min_length=2, max_length=255)
    grade: StudentGrade
    email: EmailStr
    password: str = Field(min_length=8)
    confirm_password: str = Field(min_length=8)

    @field_validator("password")
    @classmethod
    def password_strength(cls, value: str) -> str:
        return validate_strong_password(value)

    @model_validator(mode="after")
    def passwords_match(self):
        if self.password != self.confirm_password:
            raise ValueError("Passwords do not match")
        return self


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class GoogleAuthRequest(BaseModel):
    id_token: str


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    email: str
    display_name: str
    grade: str | None = None
    role: UserRole
    profile: dict = {}
    is_active: bool
    created_at: datetime


class RefreshTokenRequest(BaseModel):
    refresh_token: str
