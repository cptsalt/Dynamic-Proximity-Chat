function init()
    -- world.sendEntityMessage(receiverEntityId, "scc_add_message", newMsg)
    message.setHandler("dpc_world_message", function(_, _, data)
        if data.recId then
            world.sendEntityMessage(data.recId, "scc_add_message", data)
        end
    end)
end
