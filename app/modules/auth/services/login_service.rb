module Auth
  module Services
    class LoginService
      def self.call(name)
        new(name).call
      end

      def initialize(name)
        @name = name
      end

      def call
        validate!
        user = find_or_create_user
        { access_token: user.access_token }
      end

      private

      def find_or_create_user
        user = User.find_by(name: @name)
        return user if user

        token = JwtEncoder.encode(user_payload)
        User.create!(name: @name, access_token: token)
      end

      def user_payload
        {
          username: @name,
          iat: Time.current.to_i
        }
      end

      def validate!
        raise ArgumentError, "name is required" if @name.blank?
      end
    end
  end
end
