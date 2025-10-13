# Features

This directory contains feature-specific modules for the BlueBoxy app. Each feature is self-contained with its own views, view models, and feature-specific logic.

## Structure

- **Auth**: Authentication and authorization flows
- **Profile**: User profile management and settings
- **Assessment**: Assessment creation, editing, and management
- **Activities**: Activity tracking and management
- **Messages**: Messaging and communication features
- **Calendar**: Calendar integration and scheduling
- **Events**: Event creation and management

## Architecture

Each feature should follow this structure:

```
FeatureName/
├── Views/
├── ViewModels/
├── Models/ (feature-specific)
└── Services/ (feature-specific)
```

## Usage

Features should be loosely coupled and communicate through:
- Shared models from Core
- Navigation coordinators
- Dependency injection