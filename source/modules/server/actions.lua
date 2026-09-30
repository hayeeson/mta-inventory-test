ItemActions = {
    [1] = function(player)
        setPedAnimation(player, 'vending', 'vend_drink2_p', 2000, false, false, false, false);
        Notify.server(player, 'Você bebeu uma Pepsi.', 'info');
        return true;
    end;

    [2] = function(player)
        local health = getElementHealth(player);

        if health >= 100 then
            Notify.server(player, 'Sua vida já está cheia.', 'error');
            return false;
        end;

        setElementHealth(player, math.min(100, health + 25));
        Notify.server(player, 'Você usou uma bandagem.', 'info');
        return true;
    end;
};