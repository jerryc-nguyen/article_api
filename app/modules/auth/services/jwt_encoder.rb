module Auth
  module Services
    class JwtEncoder
      ALGORITHM = "HS256"

      def self.encode(payload)
        new.encode(payload)
      end

      def self.decode(token)
        new.decode(token)
      end

      def encode(payload)
        JWT.encode(payload.merge(iat: Time.current.to_i), secret, ALGORITHM)
      end

      def decode(token)
        JWT.decode(token, secret, true, algorithm: ALGORITHM).first
      end

      private

      def secret
        Rails.application.secret_key_base
      end
    end
  end
end
