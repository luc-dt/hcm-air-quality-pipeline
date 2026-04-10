# Kestra Docker Compose Workflow & Core Concepts

This document explains the workflow of the `docker-compose.yml` file used for running Kestra, alongside the fundamental Docker concepts that make it possible.

so, the purpose of volumes, images, containers. why do we need them? and are they connect together?


That is the perfect question to ask. To understand Docker, you have to understand why these three pieces exist and how they link together.

Here is the "why" for each piece and how they connect to form your Kestra environment.

### 1. Images: The "Why"
*   **The Problem:** In the past, if you wanted to install Kestra or PostgreSQL on your computer, you had to install specific versions of Java, download libraries, configure system settings, and hope it didn't conflict with other software on your PC. It was messy and often broke ("It works on my machine, but not yours!").
*   **The Solution (Images):** An Image solves this by pre-packaging everything into an immutable, frozen box. The Kestra team built a perfect environment with the exact right versions of Linux, Java, and Kestra code. They wrapped it up and called it `kestra/kestra:v1.1.0`.
*   **Why we need them:** They guarantee that exactly the same software runs identically for you, for me, and on a production server. No installation mess, no dependency conflicts.

### 2. Containers: The "Why"
*   **The Problem:** An image is just a static file sitting on your hard drive (like a `.exe` or a `.app` file). It doesn't do anything until you run it. Furthermore, if you run multiple applications, you don't want them crashing into each other.
*   **The Solution (Containers):** A container is the actual running process spawned from the image. It runs in an isolated "bubble." The Kestra container believes it is on its own private server. It can't break your Windows machine, and your Windows machine's software can't interfere with Kestra.
*   **Why we need them:** They provide a safe, isolated, and highly reproducible way to execute applications. You can start, stop, or delete a container in seconds without leaving a trace on your host computer.

### 3. Volumes: The "Why"
*   **The Problem:** By design, Containers are ephemeral (temporary). If you delete your Postgres container, everything inside its bubble is erased instantly. If this happens, you lose all your Kestra flows, your database records, and your logs. Every time you restart your PC, you would lose your work.
*   **The Solution (Volumes):** A Volume is like a USB thumb drive plugged into the container's isolated bubble. Docker takes a folder on your physical Windows hard drive and "mounts" it inside the container.
*   **Why we need them:** Volumes allow data to survive even if the container is destroyed. When the Postgres container writes data, it's actually writing it directly to your Windows hard drive. If the container is deleted and you spin up a brand new Postgres container tomorrow, it plugs back into that same volume and all your databases are right where you left them.

### How They Connect Together
They operate in a very specific lifecycle. Here is how they connect in your Kestra setup:

*   **Image $\rightarrow$ Container:** Docker downloads the `postgres:17` Image from the internet. It uses that blueprint to spin up a running Container.
*   **Volume $\rightarrow$ Container:** As the container spins up, Docker attaches the `postgres-data` Volume to it. The container is told, "Whenever you need to save database files, put them in this specific folder." Because that folder is a volume, the data is safely persisted outside the container's temporary bubble.
*   **Container $\rightarrow$ Container (Network):** Finally, you have a Postgres container and a Kestra container running. How do they connect? Docker automatically creates an invisible virtual Wi-Fi network. Both containers are connected to it. The Kestra container looks for the Postgres container on this network, connects to it, and says, "I'm ready to start orchestrating workflows, store my data!"

*In short: Images give you the software, Containers run the software, and Volumes save the software's homework.*

---

## 2. The Step-by-Step docker-compose Workflow

When you run `docker compose up`, Docker orchestrates these concepts precisely. Here is the process for your Kestra environment:

### Step 1: Persistent Storage Initialization (Volumes)
Docker first sets up the foundation by creating two persistent volumes as defined in the file:
*   `postgres-data`: Persists the PostgreSQL database (metadata, execution history, flow definitions).
*   `kestra-data`: Persists Kestra's internal file storage (task outputs, logs, artifacts).

### Step 2: Database Startup (`postgres` service)
Docker pulls the `postgres:17` **Image** and spins up a running **Container**.
*   It provisions a database named `kestra` with the configured credentials.
*   It mounts the `postgres-data` **Volume** so tables are saved securely to your host machine's disk.
*   **Healthcheck Blocker:** The Postgres container runs a `pg_isready` check every 30 seconds. Downstream services will not start until this check confirms the database is fully initialized and accepting connections.

### Step 3: Kestra Engine Startup (`kestra` service)
Once PostgreSQL is flagged as "healthy", Docker pulls the `kestra/kestra:v1.1.0` **Image** and starts the Kestra **Container**.
*   **Mode:** It starts in `standalone` mode, meaning the Web UI, API Server, Task Executor, and Scheduler are all spun up inside this one container.

#### Crucial Volume Mounts for Kestra:
*   **The Docker Socket (`/var/run/docker.sock`):** This critical mapping gives the Kestra container access to the host machine's Docker engine. When a Kestra flow uses Docker tasks (e.g., dbt or Airbyte), Kestra uses this socket to spin up "sibling" containers on your local machine.
*   **Service Account Keys (`../keys:/keys:ro`):** Securely mounts local GCP service account keys as read-only, giving workflows access to Google Cloud.
*   **Internal Storage (`kestra-data:/app/storage`):** Plugs in the volume created in Step 1.

#### Dynamic Configuration:
The `KESTRA_CONFIGURATION` environment variable tells the Kestra container how to behave:
*   Connects to the PostgreSQL container backing it over the internal Docker network.
*   Enables Basic Authentication (`admin@kestra.io` / `Admin1234!`).
*   Configures Kestra to store flow metadata/queues in Postgres, and file payloads in the local storage volume.

### Step 4: System Accessibility
Finally, Docker exposes ports to your host machine:
*   `8080`: You can access the Kestra Web UI by navigating to `http://localhost:8080`.
*   `8081`: Exposes Kestra's management and metrics endpoints.

### Summary
1. **Download & Build:** Docker downloads the specific **Images** (blueprints).
2. **Mount Data:** Docker creates **Volumes** to ensure data survives.
3. **Run & Isolate:** Docker spins up the isolated **Containers**.
4. **Network:** Docker places both containers on an internal network so Kestra can connect to Postgres seamlessly.
