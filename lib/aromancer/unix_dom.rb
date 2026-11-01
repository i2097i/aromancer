module Aromancer
  class UnixDom

    def self.render_arena
      arena = Aromancer::Storage.get_arena
      return unless arena.present?

      # Aromancer.arena_directory
      # todo:
    end

  end
end