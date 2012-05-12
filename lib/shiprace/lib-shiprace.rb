require 'wcnh'

module Shiprace

  MAX_RACERS = 10
  RACE_OBJ = "#639"
  RACE_CHAN = "100.00"
  RACE_HANDLE = "ESRL Announcer"
  FILE_SHIPS = File.expand_path('./ships.txt', File.dirname(__FILE__))
  FILE_NAMES = File.expand_path('./names.txt', File.dirname(__FILE__))

  def self.purchase(dbref, skill=0, wager=10)
    wallet = Econ::Wallet.find_or_create_by(id: dbref)
    bank = Econ::Wallet.find_or_create_by(id: RACE_OBJ)
    weights = Racer.all.map { |racer| racer.weight(self.build_weights(skill)) }

    return "> ".red + "Betting is currently closed." unless Racer.all.length > 0
    return "> ".red + "You need at least 10c to place a bet." unless wallet.balance > wager
    return "> ".red + "You cannot have more than 3 tickets for one race." unless Ticket.where(dbref: dbref).length < 3 || R.orflags(R["enactor"], 'Wr')
    return "> ".red + "Wager must be between 10c and 1000c." unless wager >= 10 && wager <= 1000

    racer = Racer.all.to_a.random(weights)
    ticket = racer.tickets.create!(dbref: dbref, wager: wager)
    
    wallet.balance -= wager
    bank.balance += wager
    wallet.save
    bank.save

    Logs.log_syslog("SHIPRACE","#{R.penn_name(R["enactor"])} purchased a race ticket for #{wager}c.")
    return "> ".green + "You placed a bet of #{wager}c on the #{racer.ship} piloted by #{racer.name}."
  end

  def self.build_weights(skill)
    case skill
        when 2
          hash = {1 => 3, 2 => 3, 3 => 2, 4 => 2, 5 => 1, 6 => 1}
        when 3
          hash = {1 => 1, 2 => 1, 3 => 1, 4 => 1, 5 => 1, 6 => 1}
        when 4
          hash = {1 => 1, 2 => 2, 3 => 3, 4 => 3, 5 => 2, 6 => 1}
        when 5
          hash = {1 => 1, 2 => 1, 3 => 2, 4 => 2, 5 => 3, 6 => 3}
        when skill > 5
          hash = {1 => 1, 2 => 2, 3 => 3, 4 => 4, 5 => 5, 6 => 6}
        else
          hash = {1 => 6, 2 => 5, 3 => 4, 4 => 3, 5 => 2, 6 => 1}
        end
    
    return hash
  end
  
  def self.tickets
    tickets = Ticket.all
    
    return "> ".red + "No tickets purchased in the current race." unless tickets.count > 0
    
    ret = titlebar("Race Tickets Purchased") + "\n"
    ret << " Buyer(Gambling)".ljust(23).yellow + "Ship".ljust(24).yellow + "Pilot(Skill)".ljust(20).yellow + "Wager".yellow + "\n"
    
    tickets.each do |ticket|
      player_skill = R.u("#112/fn.get.skill", ticket.dbref, "gambling").to_i
      ret << " #{R.penn_name(ticket.dbref)}(#{player_skill})".ljust(23)
      ret << ticket.racer.ship.ljust(24)
      ret << "#{ticket.racer.name}(#{ticket.racer.skill})".ljust(20) 
      ret << ticket.wager.to_s + "\n"
    end
    
    ret << footerbar
    ret
  end

  def self.buildroster
    names = File.open(FILE_NAMES, 'r') { |file| file.readlines }
    names.each { |name| name.chomp! }
    names.shuffle!
    
    ships = File.open(FILE_SHIPS, 'r') { |file| file.readlines }
    ships.each { |ship| ship.chomp! }
    ships.shuffle!
    
    MAX_RACERS.times { Racer.create!(name: names.pop(2).join(' '), ship: ships.pop) }

    return Racer.all.length
  end

  def self.roster
    roster = Racer.all
    bank = Econ::Wallet.find_or_create_by(id: RACE_OBJ)
    
    return "> ".red + "The race roster is currently empty." unless roster.length > 0
    
    ret = titlebar("Racing League Roster") + "\n"
    ret << " ## Ship".ljust(35).yellow + "Pilot".yellow + "\n"
    
    roster.each_with_index do |racer, num|
      ret << " #{num.next.to_s.ljust(2)} #{racer.ship.ljust(30)} #{racer.name}\n"
    end
    
    ret << "\n"
    ret << "Estimated Jackpot: ".yellow + (bank.balance * 0.75).to_i.to_s + "\n"
    ret << footerbar
    ret
  end

  def self.runrace
    racers = Racer.all.sort { |a, b| a.skillcheck <=> b.skillcheck }.reverse
    turn1, turn2 = racers.shuffle.first, racers.shuffle.first
    victor = racers.first
    winners = victor.tickets
    bank = Econ::Wallet.find_or_create_by(id: RACE_OBJ)
    pot = (bank.balance * 0.75).to_i

    Comms.channel_emit(RACE_CHAN,RACE_HANDLE,"Welcome to the Enigma Sector Racing League!")
    Comms.channel_emit(RACE_CHAN,RACE_HANDLE,"We have #{racers.length} competitors in tonight's race through the Damioyn System!  Use race/roster to check the roster!")
    Comms.channel_emit(RACE_CHAN,RACE_HANDLE,"3.. 2.. 1.. And they're off!")
    Comms.channel_emit(RACE_CHAN,RACE_HANDLE,"As they pass Damioyn III, #{turn1.name} in the #{turn1.ship} is in the lead!")
    Comms.channel_emit(RACE_CHAN,RACE_HANDLE,"#{turn2.name} in the #{turn2.ship} is leading the pack as they pass Damioyn VI!")
    Comms.channel_emit(RACE_CHAN,RACE_HANDLE,"At the Damioyn VIII finish line, it's the #{victor.ship} piloted by #{victor.name}!")
    Comms.channel_emit(RACE_CHAN,RACE_HANDLE,"There were #{winners.length} winning tickets with a jackpot of #{pot} credits.")

    if winners.length > 0
      bank.balance -= pot
      bank.save
      
      winning_players = winners.map { |winner| R.penn_name(winner.dbref) }.uniq
      Logs.log_syslog("SHIPRACE", "Completing race.  Jackpot #{pot}. #{winners.length} winners: #{winning_players.itemize}")
    else
      Logs.log_syslog("SHIPRACE", "Completing race.  No winners.")
    end
    
    winners.each do |winner|
      winnings = pot / winners.length
      wallet = Econ::Wallet.find_or_create_by(id: winner.dbref)
      
      wallet.balance += winnings
      wallet.save
      R.mailsend(winner.dbref,"Ship Race Winner!/You won #{winnings} credits in a ship race by betting on the #{victor.ship} piloted by #{victor.name}!")
    end

    Ticket.destroy_all
    Racer.destroy_all
    self.buildroster

    return
  end

end

