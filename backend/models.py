# models.py

import uuid
from datetime import datetime
from enum import Enum
from typing import List, Optional, Literal, Union, Annotated

from pydantic import BaseModel, Field

# --- Core Data Models (mirroring Swift) ---

class Priority(str, Enum):
    low = "low"
    medium = "medium"
    high = "high"

class Task(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    title: str
    description: Optional[str] = None
    is_completed: bool = False
    priority: Optional[Priority] = None
    creation_date: datetime = Field(default_factory=datetime.utcnow)
    deadline: Optional[datetime] = None

class Sender(str, Enum):
    user = "user"
    bot = "bot"

class ChatMessage(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    text: str
    sender: Sender

# --- API Request Body Model ---

class AppState(BaseModel):
    tasks: List[Task]
    chatHistory: List[ChatMessage]

# --- API Response Body Model ---
# We'll use a simpler approach without discriminated unions to avoid Pydantic version conflicts

from typing import Dict, Any

class ApiResponse(BaseModel):
    chat_response: str
    actions: List[Dict[str, Any]]  # List of action dictionaries
    
    model_config = {"use_enum_values": True} 