### Running the Application

Start the application with:

```bash
docker compose up --build
```

Then open [http://localhost:3000](http://localhost:3000).

The database is automatically seeded and the application is ready to use.

### Testing

Run the test suite with:

```bash
docker compose --profile test run --rm test
```

Run RuboCop with:

```bash
docker compose --profile test run --rm --no-deps test bundle exec rubocop
```

### Architecture

The main architectural decisions are documented in [Architecture Decisions](docs/ARCHITECTURE.md).

### Deployment

The application is containerized with Docker and can be deployed to a container-based hosting platform.

Production deployment requirements and considerations are documented in [Deployment](docs/DEPLOYMENT.md).
