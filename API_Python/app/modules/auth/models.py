from pydantic import BaseModel, Field


class LoginInput(BaseModel):
    username: str = Field(..., min_length=1, max_length=80)
    password: str = Field(..., min_length=1)
