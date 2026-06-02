require "jwt"

module Auth
  module Services
    class JwtEncoder
      ALGORITHM = "HS256"

      def self.encode(payload)
        JWT.encode(payload, secret, ALGORITHM)
      end

      def self.decode(token)
        JWT.decode(token, secret, true, algorithm: ALGORITHM).first
      end

      def self.secret
        Rails.application.secret_key_base
      end
    end
  end
end
