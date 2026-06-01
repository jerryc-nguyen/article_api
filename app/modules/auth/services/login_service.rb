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
        user = User.find_or_create_by!(name: @name)
        token = JwtEncoder.encode({ username: @name, user_id: user.id })
        { access_token: token }
      end

      private

      def validate!
        raise ArgumentError, "name is required" if @name.blank?
      end
    end
  end
end
