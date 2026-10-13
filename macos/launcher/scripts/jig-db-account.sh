# Dedicated database account (v2.0). Sourced after jig-db.sh:
#     . "$SCRIPT_DIR/jig-db.sh"; . "$SCRIPT_DIR/jig-db-account.sh"
# jig_app may only use the system's database; root is no longer needed after
# installation or update, so the customer can protect root with a password.
# macOS ships bash 3.2: keep this file free of bash 4 syntax.

JIG_APP_DB_USER=jig_app

jig_random_password() {
    LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom 2>/dev/null | head -c 24
}

# Uses the loaded connection (an account that may create users).
jig_db_drop_app_account() {
    jig_mysql -e "DROP USER IF EXISTS '$JIG_APP_DB_USER'@'localhost'; DROP USER IF EXISTS '$JIG_APP_DB_USER'@'127.0.0.1'; DROP USER IF EXISTS '$JIG_APP_DB_USER'@'::1';" >/dev/null 2>&1
}

# jig_db_ensure_app_account <package_dir>
# Switches app/application.properties from root to jig_app. Does nothing when
# the settings already use another account. Returns 1 on failure with the
# settings unchanged. JIG_DB_ACCOUNT_CREATED=1 when this call created jig_app.
# Afterwards JIG_DB_* still describe the account used before (root).
jig_db_ensure_app_account() {
    local props="$1/app/application.properties" pw existed sql="" h
    JIG_DB_ACCOUNT_CREATED=0
    jig_db_load "$1" || { echo "[ERROR] Cannot read the database settings or find MySQL (XAMPP)."; return 1; }
    if [ "$JIG_DB_USER" != "root" ]; then
        echo "    Database account: $JIG_DB_USER (kept)"
        return 0
    fi
    pw="$(jig_random_password)"
    [ "${#pw}" -eq 24 ] || { echo "[ERROR] Could not generate a database password."; return 1; }
    existed="$(jig_mysql -N -B -e "SELECT COUNT(*) FROM mysql.user WHERE User='$JIG_APP_DB_USER'" 2>&1)" ||
        { echo "[ERROR] Cannot read the MySQL accounts: $existed"; return 1; }
    [ "$existed" = "0" ] && JIG_DB_ACCOUNT_CREATED=1
    for h in localhost 127.0.0.1 ::1; do
        sql="$sql CREATE USER IF NOT EXISTS '$JIG_APP_DB_USER'@'$h' IDENTIFIED BY '$pw';
            ALTER USER '$JIG_APP_DB_USER'@'$h' IDENTIFIED BY '$pw';
            GRANT ALL PRIVILEGES ON \`$JIG_DB_NAME\`.* TO '$JIG_APP_DB_USER'@'$h';"
    done
    # Create the account, prove it can read the real data, then save it in the
    # settings (made owner-only first, since it will hold the password).
    if jig_mysql -e "$sql" &&
       jig_db_run_as "$JIG_APP_DB_USER" "$pw" mysql -N -B -e "SELECT COUNT(*) FROM users" "$JIG_DB_NAME" >/dev/null 2>&1 &&
       chmod 600 "$props" &&
       jig_props_set "$props" spring.datasource.username "$JIG_APP_DB_USER" &&
       jig_props_set "$props" spring.datasource.password "$pw"; then
        echo "    Database account: $JIG_APP_DB_USER (password saved in app/application.properties)"
        return 0
    fi
    [ "$JIG_DB_ACCOUNT_CREATED" = "1" ] && jig_db_drop_app_account
    JIG_DB_ACCOUNT_CREATED=0
    echo "[ERROR] Could not set up the database account $JIG_APP_DB_USER."
    return 1
}
