# frozen_string_literal: true

require 'zlib'

namespace :db do
  desc "Release any stuck advisory locks (fixes ConcurrentMigrationError)"
  task release_locks: :environment do
    puts "🔓 Checking for stuck migration locks..."
    
    begin
      conn = ActiveRecord::Base.connection
      
      # Find the advisory lock key Rails uses for migrations
      # Rails uses a hash of the database name as the lock key
      db_name = conn.current_database
      lock_key = Zlib.crc32(db_name).to_i & 0x7fffffff
      
      puts "   Database: #{db_name}, Lock key: #{lock_key}"
      
      # Check if there's a session holding this lock
      result = conn.execute(<<~SQL)
        SELECT pid, usename, application_name, state, query_start, query
        FROM pg_stat_activity 
        WHERE pid IN (
          SELECT pid FROM pg_locks 
          WHERE locktype = 'advisory' 
          AND classid = #{lock_key}
        )
        AND pid != pg_backend_pid()
      SQL
      
      if result.any?
        puts "⚠️  Found #{result.count} session(s) holding migration locks:"
        result.each do |row|
          puts "   PID: #{row['pid']}, User: #{row['usename']}, State: #{row['state']}"
          puts "   Query: #{row['query']&.truncate(100)}"
          
          # Terminate the blocking session
          puts "   🔪 Terminating PID #{row['pid']}..."
          conn.execute("SELECT pg_terminate_backend(#{row['pid']})")
        end
        
        # Wait a moment for the termination to take effect
        sleep 1
        puts "✅ Blocking sessions terminated"
      else
        puts "✅ No blocking sessions found"
      end
      
      # Also release any locks held by current session (just in case)
      conn.execute("SELECT pg_advisory_unlock_all()")
      
    rescue => e
      puts "⚠️  Lock check error: #{e.message}"
      # Don't fail the build - continue and hope for the best
    end
  end

  desc "Safe migrate that releases locks first"
  task safe_migrate: [:release_locks, :migrate] do
    puts "✅ Safe migration complete"
  end
end
