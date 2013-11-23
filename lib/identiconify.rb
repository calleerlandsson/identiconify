require "identiconify/version"
require "chunky_png"
require "digest"

module Identiconify
  class Identicon
    DEFAULT_HASH_PROVIDER = ->(string) {
      Digest::SHA1.hexdigest(string).to_i(16)
    }

    attr_reader :string,
                :square_size,
                :row_count,
                :size,
                :inverse_offset,
                :colors,
                :hash_provider

    def initialize(string, options={})
      @string = string
      @size = options.fetch(:size) { 250 }
      @row_count = 5
      @square_size = @size / @row_count
      # Since we can't draw subpixels we need to calculate how much we have to
      # offset the inverted version of the identicon to not create gaps or
      # overlaps in the middle of the image.
      @inverse_offset = @size - @square_size * @row_count
      @colors = options.fetch(:colors) { :default }.to_sym
      @hash_provider = options.fetch(:hash_provider) { DEFAULT_HASH_PROVIDER }
    end

    def column_count
      row_count.even? ? row_count/2 : row_count/2+1
    end

    def color_for_hash(hash)
      # Use the three first bytes of the hash to generate a color
      r = hash & 0xff
      g = (hash >> 8) & 0xff
      b = (hash >> 16) & 0xff
      transform_color ChunkyPNG::Color.rgb(r,g,b)
    end

    def greyscale(color)
      ChunkyPNG::Color.to_grayscale(color)
    end

    def tint(color)
      r = ChunkyPNG::Color.r(color)
      g = ChunkyPNG::Color.g(color)
      b = ChunkyPNG::Color.b(color)
      r += (0.3*(255-r)).round
      g += (0.3*(255-g)).round
      b += (0.3*(255-b)).round
      ChunkyPNG::Color.rgb(r,g,b)
    end

    def transform_color(color)
      case colors
      when :bw then greyscale(color)
      when :tinted then tint(color)
      else color
      end
    end

    def to_png_blob
      hash = hash_provider.call(string)

      color = color_for_hash(hash)
      bg_color = ChunkyPNG::Color::TRANSPARENT

      # Remove the used three color bytes
      hash >>= 24

      png = ChunkyPNG::Image.new(size, size, bg_color)
      0.upto(row_count-1).each do |row|
        0.upto(column_count-1).each do |column|
          if hash & 1 == 1
            x0 = column*square_size
            y0 = row*square_size
            x1 = (column+1)*square_size-1
            y1 = (row+1)*square_size-1
            png.rect(x0, y0, x1, y1, color, color)

            # Inverse the x coordinates making the image mirrored vertically
            x0 = size-(column+1)*square_size-inverse_offset
            x1 = size-column*square_size-inverse_offset-1
            png.rect(x0, y0, x1, y1, color, color)
          end
          hash >>= 1
        end
      end
      png.to_blob :fast_rgba
    end
  end
end
