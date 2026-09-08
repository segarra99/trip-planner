## Application

The Rails application should run in a production environment using the existing Docker image.

The deployment platform needs to provide:

- A container runtime
- Persistent network access to the database
- Environment variable configuration
- HTTPS
- Application health checks
- Application logs

The application should run with `RAILS_ENV=production`.

## Database

The application requires PostgreSQL with the PostGIS extension.

The production database should be hosted separately from the application container rather than running PostgreSQL inside the same container.

The deployment process should:

1. Provision the PostgreSQL database.
2. Enable the PostGIS extension.
3. Configure the application's database connection.
4. Run Rails database migrations.
5. Import the required locations, POIs and categories.

Database credentials should be provided through the deployment platform's secret management rather than committed to the repository.

## Configuration

Production configuration should be provided through environment variables or a secret management system.

At minimum, the application requires:

- `RAILS_ENV=production`
- `DATABASE_URL`
- Rails secret configuration required by the application

Secrets and credentials should not be stored in the repository or included in the Docker image.

## Docker Image

The Docker image should be built from the application's existing Docker configuration.

A typical deployment flow is:

1. Build the Docker image.
2. Push the image to a container registry.
3. Deploy the image to the container hosting platform.
4. Run database migrations.
5. Start the Rails application.

Using the same Docker image for local and production environments reduces differences between environments.

## Data Import

The initial dataset needs to be imported after the production database has been created and the migrations have been executed.

The import process should be run as a deployment or release step rather than during application startup.

This avoids importing the same data every time a new application container starts.

## HTTPS

The application should be exposed through HTTPS in production.

TLS termination can be handled by the hosting platform or a reverse proxy/load balancer, while the Rails application can continue to run inside the container.

## Health Checks

The existing Rails health check endpoint can be used to determine whether the application is running correctly.

The deployment platform should use this endpoint for container or service health checks.

## Logging and Monitoring

Application logs should be collected by the hosting platform rather than stored only inside the container.

At minimum, production monitoring should cover:

- Application errors
- HTTP response errors
- Container health
- Database availability
- Resource usage

Database backups should also be enabled through the chosen database provider.

## Scaling

The Rails application is stateless, so multiple application containers can be run behind a load balancer if required.

The database remains a shared resource and would need to be scaled independently.

For higher traffic, additional considerations would include:

- Database connection limits
- Database read replicas
- Caching
- Background jobs
- Container autoscaling
- Monitoring and alerting

These are not required for the scope of this challenge but would become relevant as traffic increases.

## External Routing Service

The frontend uses OSRM to calculate and display driving routes.

This is an external dependency and therefore needs to be considered when deploying the application.

The public OSRM service is suitable for development and a small demonstration, but a production application with significant traffic should use an appropriate routing service or a self-hosted routing infrastructure.

## Production Considerations

The application is intentionally kept simple for the scope of the challenge.

A production deployment would additionally require:

- Secure secret management
- Automated database backups
- HTTPS
- Application and infrastructure monitoring
- Error alerting
- Resource and database capacity planning
- A controlled deployment and rollback process

The exact infrastructure can vary depending on the hosting provider, expected traffic and operational requirements. The Docker-based architecture allows the application to be deployed to different container hosting platforms without changing the application itself.
