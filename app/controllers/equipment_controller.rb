class EquipmentController < ApplicationController

  include ApplicationHelper

  # Update
  def update
    ship = current_user.active_spaceship

    # Return if current user is not docked
    render(json: {}, status: 400) && (return) if !current_user.docked

    # Update items which are not equipped anymore
    ids = []
    if params[:ids]
      ids = ids + params[:ids][:main] if params[:ids][:main]
      ids = ids + params[:ids][:utility] if params[:ids][:utility]
    end

    ship.get_equipped_equipment.each do |item|
      loader = item.loader
      if !ids || !ids.include?(loader)
        # check black hole
        render(json: { error_message: I18n.t('errors.clear_storage_first') }, status: 400) && (return) if item.loader.include?("equipment.storage") && (current_user.active_spaceship.get_weight > 0)

        Item.give_to_user(loader: loader, user: current_user, amount: 1)
        item.delete && next
      else
        ids.slice!(ids.index(loader))
      end
    end

    ids.each do |loader|

      # Find item with id
      item = Item.find_by(loader: loader, spaceship: ship, equipped: false) rescue nil

      # Item and item belongs to spaceship and item's spaceship is ship of user
      if item

        # Equip item
        if item.get_attribute('slot_type') == "main"
          if ship.get_free_main_slots > 0
            if item.count > 1
              item.update_columns(count: item.count - 1)
              Item.create(loader: item.loader, spaceship: ship, equipped: true)
            else
              item.update_columns(equipped: true)
            end
          else
            render(json: {}, status: 400) && (return)
          end
        elsif item.get_attribute('slot_type') == "utility"
          if ship.get_free_utility_slots > 0
            if item.count > 1
              item.update_columns(count: item.count - 1)
              Item.create(loader: item.loader, spaceship: item.spaceship, equipped: true)
            else
              item.update_columns(equipped: true)
            end
          else
            render(json: {}, status: 400) && (return)
          end
        else
          render(json: {}, status: 400) && (return)
        end

      else
        render(json: {}, status: 400) && (return)
      end
    end

    render(json: { defense: ship.get_defense, storage: ship.get_storage_capacity, align: ship.get_align_time, target: ship.get_target_time }, status: 200) && (return)
  end

  def switch
    if params[:id]
      item = Item.find(params[:id]) rescue nil
      if item && current_user.active_spaceship&.get_main_equipment.map(&:id).include?(item.id) && current_user.can_be_attacked
        item.update_columns(active: !item.active)

        if (current_user.reload.active_spaceship.get_main_equipment(true).count == 1) && !current_user.equipment_worker
          EquipmentWorker.perform_async(current_user.id)
        end

        render(json: { type: item.get_attribute('type') }, status: 200) && (return)
      end
    end
    render json: {}, status: 400
  end

  def info
    if params[:loader]
      render partial: 'equipment/info', locals: { item: params[:loader] }
    end
  end
end
