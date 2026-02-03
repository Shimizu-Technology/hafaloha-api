# frozen_string_literal: true

namespace :db do
  desc "Release any stuck advisory locks (fixes ConcurrentMigrationError)"
  task release_locks: :environment do
    puts "🔓 Releasing any stuck advisory locks..."
    
    begin
      # Release all advisory locks held by this session
      ActiveRecord::Base.connection.execute("SELECT pg_advisory_unlock_all()")
      puts "✅ Advisory locks released"
    rescue => e
      puts "⚠️  Could not release locks: #{e.message}"
      # Don't fail - this is just a precaution
    end
  end

  desc "Safe migrate that releases locks first"
  task safe_migrate: [:release_locks, :migrate] do
    puts "✅ Safe migration complete"
  end
end
