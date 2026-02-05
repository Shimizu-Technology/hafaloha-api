class ImageUploadService
  attr_reader :file, :options

  def initialize(file, options = {})
    @file = file
    @options = options
  end

  def upload
    validate_file!

    blob = ActiveStorage::Blob.create_and_upload!(
      io: file_io,
      filename: sanitized_filename,
      content_type: file_content_type
    )

    {
      id: blob.id,
      filename: blob.filename.to_s,
      content_type: blob.content_type,
      byte_size: blob.byte_size,
      url: blob_url(blob),
      signed_id: blob.signed_id,
      key: blob.key
    }
  end

  def self.delete(blob_id)
    blob = ActiveStorage::Blob.find(blob_id)
    blob.purge
    true
  rescue ActiveRecord::RecordNotFound
    false
  end

  private

  def validate_file!
    raise ArgumentError, "No file provided" unless file.present?

    # Validate content type
    unless allowed_content_types.include?(file_content_type)
      raise ArgumentError, "Invalid file type: #{file_content_type}. Allowed types: #{allowed_content_types.join(', ')}"
    end

    # Validate file size
    if file_size > max_file_size
      raise ArgumentError, "File too large: #{file_size / 1.megabyte}MB. Maximum: #{max_file_size / 1.megabyte}MB"
    end
  end

  def file_io
    if file.respond_to?(:tempfile)
      file.tempfile
    elsif file.respond_to?(:read)
      file
    else
      raise ArgumentError, "Invalid file object"
    end
  end

  def file_content_type
    if file.respond_to?(:content_type)
      file.content_type
    elsif file.respond_to?(:type)
      file.type
    else
      "application/octet-stream"
    end
  end

  def file_size
    if file.respond_to?(:size)
      file.size
    elsif file.respond_to?(:tempfile)
      file.tempfile.size
    else
      0
    end
  end

  def sanitized_filename
    original_name = if file.respond_to?(:original_filename)
      file.original_filename
    else
      options[:filename] || "upload"
    end

    name = File.basename(original_name, ".*")
    ext = File.extname(original_name)

    # Remove special characters
    name = name.gsub(/[^0-9A-Za-z.\-_]/, "_")

    # Add timestamp
    timestamp = Time.current.to_i

    "#{name}_#{timestamp}#{ext}"
  end

  def blob_url(blob)
    if Rails.env.development? || Rails.env.test?
      # Use Rails blob URL for local development
      Rails.application.routes.url_helpers.rails_blob_url(
        blob,
        host: ENV.fetch("API_BASE_URL", "http://localhost:3000")
      )
    else
      # Use S3 URL in production
      blob.url
    end
  end

  def allowed_content_types
    options[:allowed_types] || [
      "image/jpeg",
      "image/jpg",
      "image/png",
      "image/gif",
      "image/webp",
      "image/svg+xml"
    ]
  end

  def max_file_size
    options[:max_size] || 10.megabytes
  end
end
