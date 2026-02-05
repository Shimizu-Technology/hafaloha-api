# frozen_string_literal: true

require "zlib"

namespace :db do
  desc "Migrate without advisory lock (for Neon/serverless databases)"
  task migrate_without_lock: :environment do
    puts "🔓 Running migrations WITHOUT advisory lock..."
    puts "   (Safe for single-deploy environments like Render)"

    # Monkey-patch the migration lock to be a no-op
    # This is safe because Render only runs one build at a time
    ActiveRecord::Base.connection.class.class_eval do
      def supports_advisory_locks?
        false
      end
    end

    puts "✅ Advisory lock check disabled"

    # Now run migrations - they won't try to acquire the lock
    Rake::Task["db:migrate"].invoke

    puts "✅ Migrations complete"
  end

  desc "Release any stuck advisory locks"
  task release_locks: :environment do
    puts "🔓 Releasing advisory locks..."

    begin
      conn = ActiveRecord::Base.connection
      db_name = conn.current_database
      lock_key = Zlib.crc32(db_name).to_i & 0x7fffffff

      conn.execute("SELECT pg_advisory_unlock(#{lock_key})")
      conn.execute("SELECT pg_advisory_unlock_all()")
      puts "✅ Advisory locks released (key: #{lock_key})"
    rescue => e
      puts "⚠️  Could not release locks: #{e.message}"
    end
  end
end
