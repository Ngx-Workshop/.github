# <img src="https://raw.githubusercontent.com/Ba5ik7/ngx-workshop/main/images/tips-and-updates.svg" /> Ngx-Workshop.io

Welcome to Ngx-Workshop.io organization 👋

This organization is dedicated to building a modular, scalable, and educational platform for full-stack web development. Our goal is to empower developers with a hands-on ecosystem that combines Angular micro-frontends, NestJS microservices, MongoDB, and Nginx into a cohesive architecture.

### 🌌 Philosophy
The Ngx-Workshop organization is not just about building apps.
It’s about:
- Teaching through doing.
- Creating modular ecosystems that scale.
- Empowering developers to grow while contributing.

---

## Summary

Ngx-Workshop is a **modern, modular, and gamified development ecosystem**.
It provides developers with a consistent, scalable way to build micro-frontends and microservices while contributing to an ambitious platform for learning web development.

Let's build something awesome together 🚀

## Overview

Ngx-Workshop is an ecosystem built on a **poly-repo** pattern that combines:

- **Angular** (with Module Federation) for micro-frontends (MFEs)
- **NestJS** microservices for backend APIs
- **MongoDB** for data persistence
- **Nginx** as a reverse proxy
- **Docker & Docker Compose** for containerization
- **GitHub Actions** for CI/CD pipelines
- **DigitalOcean** for hosting infrastructure
- **Grafana** for monitoring and logging

This ecosystem is designed to support both **structural micro-frontends** (headers, footers, navigation) and **user journey MFEs**, as well as a consistent backend service pattern with clearly defined **bounded contexts**.

---

## Architecture & Philosophy

### Microservices
- Each NestJS microservice is responsible for **CRUD operations on a single MongoDB document type**.
- No two services should manipulate the same document.
- Services communicate over **internal VPC IPs** using RESTful HTTP (TCP support is being planned).
- Authentication/Authorization is handled by a dedicated service that also provides an **NPM package with NestJS guards**.
- All services run in Docker containers managed with **Docker Compose**, and are exposed via **Nginx reverse proxies**.
- A **seed repository** exists to guide developers through creating new services, running them locally, and following architectural patterns.

### Frontend
- Angular applications use **Module Federation** to create MFEs.
- MFEs are categorized into:
  - **Structural MFEs**: header, footer, navigation, etc.
  - **User Journey MFEs**: feature-driven applications that determine which structural MFEs to render.
- A dedicated **MFE seed repository** provides examples and onboarding instructions for creating new MFEs.

---

## MCP Gamified Learning

Ngx-Workshop is more than just an architecture. The future vision is to build an **MCP (Mission Control Platform)** that gamifies learning web development.
Users will progress through:
- **Assessment tests**
- **Interactive workshops**
- **Continuous game loops**

Thanks to the MFE architecture, the system dynamically adapts what is shown to the user, moving beyond traditional static navigation toward a more **agent-driven, personalized journey**.

---

## Getting Started

- Review the **service seed repo** to learn backend patterns.
- Review the **MFE seed repo** to learn frontend patterns.
- Explore the ecosystem repos to see real implementations.

Each seed repository contains detailed onboarding docs to help you get productive quickly.

---

## 🤝 Contributing

We welcome contributions from developers of all levels. The most important thing is to follow the established architectural guidelines and keep services and MFEs consistent.

- Follow the **bounded context rules** for microservices.
- Keep MFEs clearly scoped (structural vs user journey).
- Use the provided seeds for new services or MFEs.
