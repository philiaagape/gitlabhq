module Gitlab
  module SidekiqStatus
    class ClientMiddleware
      def call(_, job, _, _)
        Gitlab::SidekiqStatus.set(job['jid'])
        yield
      end
    end
  end
end
