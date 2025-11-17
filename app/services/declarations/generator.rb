# frozen_string_literal: true

module Declarations
  class Generator
    def initialize(contract, month, year)
      @contract = contract
      @month = month
      @year = year
    end

    def call
      work_sessions = @contract.work_sessions.where(date: period_range)

      total_minutes = work_sessions.sum(:duration_minutes)
      brut = work_sessions.sum { |ws| ws.brut }
      cp = @contract.cp(brut)

      @contract.declarations.new(
        user: @contract.user,
        employer_name: @contract.agency_label,
        month: @month,
        year: @year,
        total_minutes: total_minutes,
        brut_with_cp: brut + cp
      )
    end

    private

    def period_range
      Date.new(@year, @month, 1)..Date.new(@year, @month, -1)
    end
  end
end
