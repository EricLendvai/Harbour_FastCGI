# FastCGI Shutdown Handling in Harbour Applications (Summary)

**Date**: 2025-06-19  
**Author**: Eric Lendvai (via investigation with ChatGPT)  
**Context**: Deep investigation into the shutdown behavior of Harbour FastCGI apps under `mod_fcgid`, especially in containers (Linux), and the necessity of manual resource cleanup.

---

## 🔍 Objective

Determine whether it is necessary to implement custom shutdown/cleanup logic for a FastCGI application written in Harbour, particularly to close:

- SQL connections
- CPython interpreter
- Open file handles
- Buffers/logs

---

## 🔧 Environment

- **FastCGI binding** via [`hb_fcgi_c.c`](https://github.com/EricLendvai/Harbour_FastCGI/blob/main/hb_fcgi/hb_fcgi_c.c)
- Using `mod_fcgid` in **Apache 2.4**
- **Single-threaded mode** (due to Harbour debugger limitations)
- Deployed in **Docker/DevContainers**
- Target OS: **Ubuntu Linux (22.04)**

---

## 🔄 Signal Handling Setup

C-level signal hook was registered:

```c
signal(SIGTERM, on_termination_signal);
signal(SIGINT,  on_termination_signal);
#ifndef _WIN32
signal(SIGQUIT, on_termination_signal);
#endif
```

This was used to attempt calling Harbour-level cleanup (e.g., `hb_evalBlock()` or `s_pUserCleanup()`).

---

## 🧪 Observations

- `FCGX_Accept_r()` is a **blocking loop** and does **not return** when `SIGTERM` is received (due to `mod_fcgid` holding the socket open).
- Even with `FCGX_ShutdownPending()` and logs confirming signal reception, the Harbour cleanup block was never invoked — the signal handler executed in C, but `FCGX_Accept_r()` remained stuck.
- Apache’s `mod_fcgid` **forcefully terminates** FastCGI apps if they don’t exit on their own — usually with `SIGKILL`.

---

## ✅ Final Conclusions

| Resource Type       | Cleaned Automatically | Notes                                            |
| ------------------- | --------------------- | ------------------------------------------------ |
| SQL Connections     | ✅ (via DB timeouts)   | DB will detect lost clients after inactivity     |
| CPython Interpreter | ❌ but irrelevant      | No interpreter shutdown, but memory is freed     |
| File Handles        | ✅ Yes                 | Kernel closes them                               |
| File Buffers        | ❌ unless flushed      | Use `fflush(fp)` or unbuffered logging if needed |
| Sockets             | ✅ Yes                 | TCP connections are closed                       |
| Memory              | ✅ Yes                 | Kernel reclaims all                              |

---

## 💡 Practical Takeaways

- **Do nothing**: Let the OS and `mod_fcgid` handle cleanup.
- Flush any critical log data immediately after writing.
- Manual Harbour-level cleanup is **not guaranteed to run** due to blocking socket read in `FCGX_Accept_r()`.
- Avoid trying to bypass or break the `mod_fcgid` socket lifecycle — it's by design.
- Future use of `mod_proxy_fcgi` or a direct FastCGI socket might offer more graceful shutdown control, but for most apps: **not worth the added complexity**.

---

## 🧠 Remember

You did the work, verified all assumptions, and ruled out unnecessary complexity. This lets you move forward with **confidence**.

📦 **In containers**, this design is even more robust — let the orchestrator or Docker manage lifecycle.

---

## Additional Research: Comparing Apache FastCGI Modules

During this investigation, we also evaluated alternative Apache modules to determine if they could provide better behavior regarding graceful FastCGI shutdowns.

### 🔁 mod_fcgid (Current)

- **Pros:**
  - Actively maintained and widely used.
  - Supports automatic spawning of FastCGI workers by Apache.
  - Restarts crashed FastCGI processes automatically.
  - Simple configuration and well-documented.
- **Cons:**
  - Sends `SIGTERM` to FastCGI workers without a way to hook in-process cleanup.
  - Does not allow custom control over the socket or request loop from within the FastCGI executable.
  - FCGX_Accept_r() blocks indefinitely, which prevents Harbour cleanup routines from executing.

### 📉 mod_fastcgi (Deprecated)

- **Pros:**
  - Older and historically the origin of FastCGI on Apache.
  - Provided more fine-grained socket control.
- **Cons:**
  - No longer maintained.
  - Not included in modern Apache distributions.
  - Known compatibility and stability issues on newer systems.

### 🔀 mod_proxy_fcgi

- **Pros:**
  - Supports reverse proxying to external FastCGI processes (e.g., running in Docker containers).
  - Useful when decoupling Apache from the process lifecycle of FastCGI applications.
  - Avoids blocking behavior in `FCGX_Accept_r()` if the FastCGI server is external and socket-based.
- **Cons:**
  - Apache does not manage FastCGI worker lifecycles.
  - Developer must manually handle worker startup, recovery, and load balancing (e.g., via systemd or Docker orchestration).
  - Requires a custom supervisor solution to replace mod_fcgid's worker management.

### 🧭 Final Decision

After extensive evaluation, we chose to **stick with `mod_fcgid`** because:

- Apache handles worker management and recovery automatically.
- Our FastCGI application is single-threaded for debugging, making graceful exit handling less critical.
- CPython and SQL connections will be forcefully closed by the OS upon termination.
- The complexity and effort of switching to `mod_proxy_fcgi` outweigh its limited benefits in this context.
- Undid all changes: Using simple FCGC_Accept(), and no handling of signal messages.
