# Posthog Dart

Quick and dirty mapping for the PostHog API.

## Installation

```yaml
dependencies:
  posthog_dart:
    git:
      url: https://github.com/necodeIT/posthog_dart.git
```

## Usage

In your main method call `PostHog.init(host: 'your-api-key', host: 'example.com')`. After that you can capture events by calling `PostHog().capture()`.
