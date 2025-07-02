# PRD: Intent Router for Conversational Task Manager

## 1. Introduction/Overview

### 1.1. The Problem
Currently, every message from a user is processed by a powerful but slow and expensive Large Language Model (LLM). Many user requests are simple and direct (e.g., "add a task to buy milk"). Using a full LLM for these simple cases is inefficient.

### 1.2. The Solution
We will introduce an "Intent Router" that acts as a smart traffic controller at the beginning of our processing pipeline. This router will use a fast, local Natural Language Processing (NLP) library (spaCy) to analyze the user's message. If it recognizes a simple, direct command, it will handle it using a cheaper, faster "shortcut" path. Complex or ambiguous messages will be sent to the full LLM as they are now.

### 1.3. Goal
The primary goal is to **reduce API costs and improve response time for simple, common user requests** by handling them locally without involving the main LLM.

## 2. Goals

*   **G-1: Reduce Latency:** Decrease the average response time for simple task creation commands by at least 50%.
*   **G-2: Reduce Cost:** Eliminate OpenAI API calls for at least 20% of incoming user messages (targeting simple creations).
*   **G-3: Maintain Accuracy:** Ensure that the router only handles requests it is highly confident about, maintaining a false positive rate of less than 1%.
*   **G-4: Improve Reliability:** Provide deterministic (100% predictable) responses for the commands handled by the router.

## 3. User Stories

*   **As a user,** when I type a simple command like "add task to call the plumber," I want to receive a confirmation instantly so the app feels fast and responsive.
*   **As a user,** when I type a command to delete a task like "get rid of the 'buy bread' task," I want the system to understand my intent to delete and then quickly find the correct task to remove.
*   **As a developer,** I want to see logs that clearly show which requests were handled by the router and which were passed to the full LLM, so I can measure the feature's effectiveness.
*   **As a developer,** I want to easily adjust the rules that the router uses to identify commands, so I can improve its accuracy over time without rewriting major parts of the code.

## 4. Functional Requirements

### FR-1: System Setup
*   The system **must** install `spacy` and its small English model (`en_core_web_sm`) as a dependency.
*   The system **must** load the spaCy model once when the server starts to avoid slow first-time requests.

### FR-2: Intent Router Logic
*   The system **must** create a new `intent_router` module or section of code.
*   This router **must** analyze the user's most recent message before any other processing.
*   The router **must** use spaCy's `Matcher` to identify three distinct user intents based on predefined patterns:
    *   `CREATE_TASK` (e.g., "add", "create", "make")
        *   `DELETE_TASK` (e.g., "delete", "remove", "get rid of")
            *   `TOGGLE_COMPLETION` (e.g., "mark as done", "complete", "finish")
            *   The router **must** be case-insensitive.

            ### FR-3: Routing Path 1 - Full Shortcut (Create Task)
            *   If the `CREATE_TASK` intent is detected:
                *   **FR-3.1:** The router **must** extract the task title from the user's message.
                    *   **FR-3.2:** The router **must** generate a complete `createTask` action payload, including a new UUID and the current timestamp.
                        *   **FR-3.3:** The router **must** generate a simple confirmation message (e.g., "OK, I've added 'Call the plumber' to your list.").
                            *   **FR-3.4:** The system **must** skip all OpenAI API calls (both for embeddings and the LLM) and send the generated action/response directly to the user.

                            ### FR-4: Routing Path 2 - Partial Shortcut (Delete/Toggle)
                            *   If `DELETE_TASK` or `TOGGLE_COMPLETION` intent is detected:
                                *   **FR-4.1:** The system **must** route the request to a new, specialized processing path in the graph.
                                    *   **FR-4.2:** This new path **must** first use the existing embeddings model to find the most likely candidate tasks the user is referring to.
                                        *   **FR-4.3:** This new path **must** then make a lightweight call to the LLM. The prompt for this call will be highly focused, asking only for the ID of the task to be acted upon (e.g., "Given the user wants to delete a task, which of these candidate tasks is the correct one?").

                                        ### FR-5: Routing Path 3 - Fallback to Full LLM
                                        *   If the router does not confidently detect any of the above intents, it **must** pass the request to the existing, full LLM agent path without any changes.

                                        ### FR-6: Logging
                                        *   The system **must** log which path was taken for every request (`Router: Create`, `Router: Delete`, `Router: Fallback`).
                                        *   When a router path is taken, the log **must** include the specific pattern that was matched.

                                        ## 5. Non-Goals (Out of Scope)

                                        *   The router **will not** handle implicit or conversational requests (e.g., "I should probably call my mom"). These will fall back to the LLM.
                                        *   The router **will not** attempt to extract complex entities like `deadlines`, `priorities`, or `descriptions` for `CREATE_TASK` requests. Any request containing these will fall back to the LLM.
                                        *   The router **will not** attempt to handle more than one action in a single command (e.g., "add task A and delete task B").
                                        *   This feature **will not** have a UI component. It is a backend-only optimization.
                                        *   A "kill switch" to disable the feature via an environment variable is **not required** for this initial implementation.

                                        ## 6. Design Considerations

                                        *   N/A (Backend only)

                                        ## 7. Technical Considerations

                                        *   **File Structure:** Implement the core router logic in a new file, `intent_router.py`, to keep the code organized. Import this into `graph.py`.
                                        *   **Graph Modification:** The existing `StateGraph` in `graph.py` will need to be modified. This will involve:
                                            *   Adding new nodes for the router and the specialized "find-and-act" paths.
                                                *   Implementing a new conditional edge after the router node to direct traffic to the correct path (`CREATE`, `DELETE`, `TOGGLE`, or `FALLBACK`).
                                                *   **Pattern Tweakability:** Define all spaCy `Matcher` patterns in a single, well-commented list or dictionary at the top of the `intent_router.py` file. This will make it easy for other developers to find and adjust the rules in the future.

                                                ## 8. Open Questions

                                                *   None at this time. The spec is considered complete for the initial implementation.gga junior developer to implement the "Intent Router" feature as we've discussed.

---

# PRD: Intent Router for Conversational Task Manager

## 1. Introduction/Overview

### 1.1. The Problem
Currently, every message from a user is processed by a powerful but slow and expensive Large Language Model (LLM). Many user requests are simple and direct (e.g., "add a task to buy milk"). Using a full LLM for these simple cases is inefficient.

### 1.2. The Solution
We will introduce an "Intent Router" that acts as a smart traffic controller at the beginning of our processing pipeline. This router will use a fast, local Natural Language Processing (NLP) library (spaCy) to analyze the user's message. If it recognizes a simple, direct command, it will handle it using a cheaper, faster "shortcut" path. Complex or ambiguous messages will be sent to the full LLM as they are now.

### 1.3. Goal
The primary goal is to **reduce API costs and improve response time for simple, common user requests** by handling them locally without involving the main LLM.

## 2. Goals

*   **G-1: Reduce Latency:** Decrease the average response time for simple task creation commands by at least 50%.
*   **G-2: Reduce Cost:** Eliminate OpenAI API calls for at least 20% of incoming user messages (targeting simple creations).
*   **G-3: Maintain Accuracy:** Ensure that the router only handles requests it is highly confident about, maintaining a false positive rate of less than 1%.
*   **G-4: Improve Reliability:** Provide deterministic (100% predictable) responses for the commands handled by the router.

## 3. User Stories

*   **As a user,** when I type a simple command like "add task to call the plumber," I want to receive a confirmation instantly so the app feels fast and responsive.
*   **As a user,** when I type a command to delete a task like "get rid of the 'buy bread' task," I want the system to understand my intent to delete and then quickly find the correct task to remove.
*   **As a developer,** I want to see logs that clearly show which requests were handled by the router and which were passed to the full LLM, so I can measure the feature's effectiveness.
*   **As a developer,** I want to easily adjust the rules that the router uses to identify commands, so I can improve its accuracy over time without rewriting major parts of the code.

## 4. Functional Requirements

### FR-1: System Setup
*   The system **must** install `spacy` and its small English model (`en_core_web_sm`) as a dependency.
*   The system **must** load the spaCy model once when the server starts to avoid slow first-time requests.

### FR-2: Intent Router Logic
*   The system **must** create a new `intent_router` module or section of code.
*   This router **must** analyze the user's most recent message before any other processing.
*   The router **must** use spaCy's `Matcher` to identify three distinct user intents based on predefined patterns:
    *   `CREATE_TASK` (e.g., "add", "create", "make")
    *   `DELETE_TASK` (e.g., "delete", "remove", "get rid of")
    *   `TOGGLE_COMPLETION` (e.g., "mark as done", "complete", "finish")
*   The router **must** be case-insensitive.

### FR-3: Routing Path 1 - Full Shortcut (Create Task)
*   If the `CREATE_TASK` intent is detected:
    *   **FR-3.1:** The router **must** extract the task title from the user's message.
    *   **FR-3.2:** The router **must** generate a complete `createTask` action payload, including a new UUID and the current timestamp.
    *   **FR-3.3:** The router **must** generate a simple confirmation message (e.g., "OK, I've added 'Call the plumber' to your list.").
    *   **FR-3.4:** The system **must** skip all OpenAI API calls (both for embeddings and the LLM) and send the generated action/response directly to the user.

### FR-4: Routing Path 2 - Partial Shortcut (Delete/Toggle)
*   If `DELETE_TASK` or `TOGGLE_COMPLETION` intent is detected:
    *   **FR-4.1:** The system **must** route the request to a new, specialized processing path in the graph.
    *   **FR-4.2:** This new path **must** first use the existing embeddings model to find the most likely candidate tasks the user is referring to.
    *   **FR-4.3:** This new path **must** then make a lightweight call to the LLM. The prompt for this call will be highly focused, asking only for the ID of the task to be acted upon (e.g., "Given the user wants to delete a task, which of these candidate tasks is the correct one?").

### FR-5: Routing Path 3 - Fallback to Full LLM
*   If the router does not confidently detect any of the above intents, it **must** pass the request to the existing, full LLM agent path without any changes.

### FR-6: Logging
*   The system **must** log which path was taken for every request (`Router: Create`, `Router: Delete`, `Router: Fallback`).
*   When a router path is taken, the log **must** include the specific pattern that was matched.

## 5. Non-Goals (Out of Scope)

*   The router **will not** handle implicit or conversational requests (e.g., "I should probably call my mom"). These will fall back to the LLM.
*   The router **will not** attempt to extract complex entities like `deadlines`, `priorities`, or `descriptions` for `CREATE_TASK` requests. Any request containing these will fall back to the LLM.
*   The router **will not** attempt to handle more than one action in a single command (e.g., "add task A and delete task B").
*   This feature **will not** have a UI component. It is a backend-only optimization.
*   A "kill switch" to disable the feature via an environment variable is **not required** for this initial implementation.

## 6. Design Considerations

*   N/A (Backend only)

## 7. Technical Considerations

*   **File Structure:** Implement the core router logic in a new file, `intent_router.py`, to keep the code organized. Import this into `graph.py`.
*   **Graph Modification:** The existing `StateGraph` in `graph.py` will need to be modified. This will involve:
    *   Adding new nodes for the router and the specialized "find-and-act" paths.
    *   Implementing a new conditional edge after the router node to direct traffic to the correct path (`CREATE`, `DELETE`, `TOGGLE`, or `FALLBACK`).
*   **Pattern Tweakability:** Define all spaCy `Matcher` patterns in a single, well-commented list or dictionary at the top of the `intent_router.py` file. This will make it easy for other developers to find and adjust the rules in the future.
