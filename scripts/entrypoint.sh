#!/bin/bash
set -e

echo "=========================================="
echo "AiiDA Docker Container Starting..."
echo "=========================================="

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL (${DB_HOST}:${DB_PORT})..."
until pg_isready -h ${DB_HOST} -p ${DB_PORT} -U ${DB_USER}; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 2
done
echo "PostgreSQL is ready!"

# Wait for RabbitMQ to be ready
echo "Waiting for RabbitMQ (${RABBITMQ_HOST}:${RABBITMQ_PORT})..."
until rabbitmq-diagnostics -q ping -h ${RABBITMQ_HOST} -p ${RABBITMQ_PORT} -u ${RABBITMQ_USER} -p ${RABBITMQ_PASSWORD}; do
  echo "RabbitMQ is unavailable - sleeping"
  sleep 2
done
echo "RabbitMQ is ready!"

# Display environment information
echo ""
echo "=========================================="
echo "Environment Configuration:"
echo "=========================================="
echo "Profile Name: ${PROFILE_NAME}"
echo "User Email: ${USER_EMAIL}"
echo "Database Host: ${DB_HOST}"
echo "Database Name: ${DB_NAME}"
echo "RabbitMQ Host: ${RABBITMQ_HOST}"
echo "Computer: ${COMPUTER_NAME} (${COMPUTER_HOSTNAME})"
echo ""

# install Aida-core
pip install aiida-core

# Check if AiiDA profile exists
echo "Checking AiiDA profile..."
if verdi profile show ${PROFILE_NAME} &> /dev/null; then
    echo "Profile '${PROFILE_NAME}' already exists."
    echo "Verifying connection..."
    verdi -n daemon show 2>&1 | head -5 || true
else
    echo "Creating AiiDA profile '${PROFILE_NAME}'..."
    
    # Setup AiiDA profile
    verdi -n profile setup \
        --profile ${PROFILE_NAME} \
        --email ${USER_EMAIL} \
        --first-name "${USER_FIRSTNAME}" \
        --last-name "${USER_LASTNAME}" \
        --institution "${USER_INSTITUTION}" \
        --db-backend postgresql \
        --db-host ${DB_HOST} \
        --db-port ${DB_PORT} \
        --db-name ${DB_NAME} \
        --db-user ${DB_USER} \
        --db-pass "${DB_PASSWORD}" \
        --repository-uri "${REPO_URI}"
    
    # Configure RabbitMQ for daemon
    echo "Configuring AiiDA daemon..."
    verdi -n daemon configure \
        --host ${RABBITMQ_HOST} \
        --port ${RABBITMQ_PORT} \
        --username ${RABBITMQ_USER} \
        --password "${RABBITMQ_PASSWORD}" \
        --vhost ${RABBITMQ_VHOST}
    
    echo "AiiDA profile created successfully!"
fi

echo ""
echo "=========================================="
echo "AiiDA Setup Complete!"
echo "=========================================="
echo "You can now use the following commands:"
echo "  verdi profile show ${PROFILE_NAME}    - Show profile info"
echo "  verdi daemon start                     - Start daemon"
echo "  verdi computer list                   - List computers"
echo "  verdi code list                       - List codes"
echo ""

# Keep container running
echo "Container will stay running. Press Ctrl+C to stop."
echo ""
exec "$@"