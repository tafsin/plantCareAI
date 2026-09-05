# plantcare_data

Flutter data adapters for PlantCare AI. This package owns Firebase repository
implementations, Firebase AI adapters, image processing, and local notification
storage/scheduling. Domain contracts remain in `plantcare_domain`; the root app
continues to own Firebase bootstrap and the final GetIt container.

Regenerate dependency injection in this order from the workspace root:

```sh
(cd packages/plantcare_data && dart run build_runner build)
dart run build_runner build
```

The first command generates `PlantcareDataPackageModule`. The second includes
that module before app-owned registrations. Registration is lazy, so Firebase
instances and `EnvironmentConfig` may remain app-owned and are available before
any data adapter is resolved.
