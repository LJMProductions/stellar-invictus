class AppearWorker
  # This Worker will be run when the user loggs in

  include Sidekiq::Worker
  sidekiq_options retry: false

  def perform(player_id)
    user = User.find(player_id) rescue nil

    # If we found a user
    if user

      # Add 1 to user online status
      user.update_columns(online: user.online + 1)

      # If only connection and user is not docked
      if (user.online == 1) && !user.docked
        # Tell everyone in the location that user has logged in
        ActionCable.server.broadcast("location_#{user.location.id}", method: 'player_appeared')
      end

      # Tell everyone in system to update their local players
      user.system.update_local_players unless user.system.wormhole?

      # Tell all users in custom chat channels to update
      user.chat_rooms.where(chatroom_type: 'custom').each do |room|
        room.update_local_players
      end
      user.chat_rooms.where(chatroom_type: 'corporation').each do |room|
        room.update_local_players
      end

      # Start Mission Worker if location is mission and user has mission
      if (user.location_location_type == 'mission') && (user.location.mission.user == user)
        MissionWorker.perform_async(user.location.id)
      end

      # Spawn Enemies if User at Expedtion Site with Enemies
      if (user.location_location_type == 'exploration_site') && (user.location_enemy_amount > 0) && (user.location.npcs.count == 0)
        (user.location_enemy_amount).times do
          EnemyWorker.perform_async(nil, user.location.id)
        end
      end

    end
  end
end
