#!/bin/ash -e
# shellcheck shell=dash

# Set up environment variables for consistent configuration
export PELICAN_HOME=${PELICAN_HOME:-"/pelican"}
export PELICAN_APP=${PELICAN_APP:-"$PELICAN_HOME/app"}
export PELICAN_CONFIG=${PELICAN_CONFIG:-"$PELICAN_HOME/config"}
export PELICAN_DATA=${PELICAN_DATA:-"$PELICAN_HOME/data"}

# Set Caddy environment variables
export XDG_DATA_HOME="$PELICAN_DATA"
export XDG_CONFIG_HOME="$PELICAN_CONFIG"

# Caddy global options
export CADDY_GLOBAL_OPTS=${CADDY_GLOBAL_OPTS:-""}
export CADDY_DOMAIN=${CADDY_DOMAIN:-"localhost"}
export CADDY_PORT=${CADDY_PORT:-"443"}

# Set critical APP_ environment variables with defaults
export APP_ENV=${APP_ENV:-production}
export APP_DEBUG=${APP_DEBUG:-false}
export APP_URL=${APP_URL:-http://localhost}

# Default values for PUID/PGID if not provided
PUID=${PUID:-1000}
PGID=${PGID:-1000}

echo "Starting with UID: $PUID, GID: $PGID"

# Function to check and update user/group IDs if needed
check_user() {
    # Update the abc user and group with the provided IDs
    if [ "$PUID" != "1000" ] || [ "$PGID" != "1000" ]; then
        echo "Updating user and group IDs..."

        # Delete and recreate the user and group with new IDs
        deluser abc
        addgroup -g "$PGID" abc
        adduser -D -u "$PUID" -G abc -h "$PELICAN_HOME" abc

        # Update file ownership efficiently, excluding vendor directory
        echo "Updating file ownership (this may take a while)..."
        # Update app directory excluding vendor
        echo "Updating app directory (excluding vendor)..."
        find "$PELICAN_APP" -path "$PELICAN_APP/vendor" -prune -o -exec chown abc:abc {} \+ 2>/dev/null || true

        # Update config and data directories
        echo "Updating config and data directories..."
        chown -R abc:abc "$PELICAN_CONFIG" "$PELICAN_DATA" 2>/dev/null || true

        echo "UID/GID update completed"
    fi
}

# Function to initialize the application
initialize_app() {
    # Check if a custom Caddyfile exists in the config volume
    CADDYFILE="$PELICAN_CONFIG/Caddyfile"
    if [ ! -f "$CADDYFILE" ]; then
        echo "No custom Caddyfile found in config volume, copying default Caddyfile"
        cp "$PELICAN_APP/Caddyfile.template" "$CADDYFILE"
        # No need to change ownership as we're already running as abc user
    else
        echo "Using custom Caddyfile from config volume"
    fi
    ln -sf "$PELICAN_CONFIG/Caddyfile" "$PELICAN_APP/Caddyfile"

    CADDY_GLOBAL_CONFIG="$PELICAN_CONFIG/caddy_global.conf"
    echo "# Generated Caddy global options" > "$CADDY_GLOBAL_CONFIG"
    echo "$CADDY_GLOBAL_OPTS" | tr ';' '\n' >> "$CADDY_GLOBAL_CONFIG"

    # Handle .env file
    ENVFILE="$PELICAN_CONFIG/.env"
    if [ ! -f "$ENVFILE" ]; then
        echo "Creating .env file with APP_ environment variables"
        # Start with empty .env file
        touch "$ENVFILE"
        
        # Add APP_KEY placeholder first
        echo "APP_KEY=" > "$ENVFILE"
        
        # Add all APP_ environment variables from current environment
        env | grep "^APP_" | grep -v "^APP_KEY=" | sort >> "$ENVFILE"
        
        # Ensure proper permissions on the new file
        if [ "$(id -u)" != "0" ]; then
            chmod g+rw "$ENVFILE"
        fi
    else
        # For existing .env files, ensure APP_KEY exists (but don't overwrite)
        if ! grep -q "^APP_KEY=" "$ENVFILE"; then
            echo "Adding APP_KEY placeholder to existing .env file"
            echo "APP_KEY=" >> "$ENVFILE"
        fi
        
        # Add any APP_ environment variables that don't exist in .env
        # Skip APP_KEY as it should be managed separately
        for VAR in $(env | grep "^APP_" | grep -v "^APP_KEY=" | cut -d= -f1); do
            if ! grep -q "^$VAR=" "$ENVFILE"; then
                echo "Adding $VAR to existing .env file"
                VALUE=$(eval echo \$VAR)
                echo "$VAR=$VALUE" >> "$ENVFILE"
            fi
        done
    fi

    # Create symlink to .env file
    ln -sf "$PELICAN_CONFIG/.env" "$PELICAN_APP/.env"

    # Check if APP_KEY is empty and generate if needed
    if grep -q "^APP_KEY=$" "$ENVFILE"; then
        echo "APP_KEY is empty, generating new key..."
        cd "$PELICAN_APP"
        php artisan key:generate
    else
        echo "APP_KEY is already set in .env file"
    fi

    # Ensure database directory exists and has proper permissions
    if [ ! -d "$PELICAN_DATA/database" ]; then
        echo "Creating database directory"
        mkdir -p "$PELICAN_DATA/database"

        # Ensure proper permissions on the new directory
        if [ "$(id -u)" != "0" ]; then
            # We're running as non-root, so make sure the directory is group-writable
            chmod g+rwx "$PELICAN_DATA/database"
        fi
    fi
    
    # Ensure the database file exists to prevent symlink errors
    if [ ! -f "$PELICAN_DATA/database/database.sqlite" ]; then
        echo "Creating empty database file"
        touch "$PELICAN_DATA/database/database.sqlite"
        chmod g+rw "$PELICAN_DATA/database/database.sqlite"
    fi
    ln -sf "$PELICAN_DATA/database/database.sqlite" "$PELICAN_APP/database/database.sqlite"

    # Make sure the db is set up
    echo "Migrating Database"
    cd "$PELICAN_APP"
    php artisan migrate --force

    echo "Optimizing Filament"
    php artisan filament:optimize

    # Set default admin credentials if not provided
    ADMIN_EMAIL=${ADMIN_EMAIL:-"pelican@example.com"}
    ADMIN_USERNAME=${ADMIN_USERNAME:-"pelican"}
    ADMIN_PASSWORD=${ADMIN_PASSWORD:-"pelican"}

    # Create default admin user if not already created
    ADMIN_FLAG_FILE="$PELICAN_CONFIG/.admin_user_created"

    if [ ! -f "$ADMIN_FLAG_FILE" ] && [ -n "$ADMIN_EMAIL" ] && [ -n "$ADMIN_PASSWORD" ]; then
        echo "Creating initial admin user..."
        if php artisan p:user:make --email="${ADMIN_EMAIL}" --username="${ADMIN_USERNAME}" --password="${ADMIN_PASSWORD}" --admin=yes; then
            echo "Admin user created successfully."
            # Create flag file to indicate admin user has been created
            touch "$ADMIN_FLAG_FILE"
            echo "$(date): Initial admin user created with username '${ADMIN_USERNAME}' and email '${ADMIN_EMAIL}'" > "$ADMIN_FLAG_FILE"
        else
            echo "Failed to create admin user."
        fi
    else
        if [ -f "$ADMIN_FLAG_FILE" ]; then
            echo "Admin user was already created previously. To create a new admin user, delete the file: $ADMIN_FLAG_FILE"
        fi
    fi

    # Setup Laravel queue worker in background
    if [ "${ENABLE_QUEUE_WORKER:-}" = "true" ]; then
        echo "Starting Laravel queue worker"
        php artisan queue:work --tries=3 &
    fi

    # Setup Laravel scheduler using supercronic in background
    if [ "${ENABLE_SCHEDULER:-}" = "true" ]; then
        echo "Starting Laravel scheduler"
        supercronic -overlapping /etc/supercronic/crontab &
    fi
}

# Main script execution
if [ "$(id -u)" = "0" ]; then
    # Check and update user/group IDs if needed
    check_user

    # Switch to abc user to run the rest of the script
    echo "Switching to abc user for the rest of the script"
    cd "$PELICAN_APP"
    exec su-exec abc:abc "$0" "$@"
else
    # Already running as non-root user, just initialize the app
    initialize_app

    # Starting FrankenPHP with both HTTP and HTTPS support
    echo "Starting FrankenPHP with both HTTP and HTTPS support (ports 80 and 443)"

    # Execute the command
    exec "$@"
fi
