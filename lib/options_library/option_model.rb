module Option
  class Model
    INVALID_PARAMETERS_MESSAGE = "Invalid parameters"
    KNOWN_OPTION_TYPES = [:call, :put]
    PERCENT_STEP_STRIKE = 2.0 / 100
    SET_STRIKE_ACCURACY = 0.1 / 100
    LAST_TRY_ACCURACY = 0.033
    MAX_CYCLES = 2000

    # A map to define methods to call based on option_type
    CALC_PRICE_METHODS = { call: Calculator.method("price_call"), put: Calculator.method("price_put") }
    CALC_DELTA_METHODS = { call: Calculator.method("delta_call"), put: Calculator.method("delta_put") }
    CALC_THETA_METHODS = { call: Calculator.method("theta_call"), put: Calculator.method("theta_put") }
    IMPLIED_VOL_METHODS = { call: Calculator.method("implied_vol_call"), put: Calculator.method("implied_vol_put") }

    attr_reader :dte, :underlying
    attr_accessor :option_type, :strike, :time, :interest, :sigma, :dividend

    def initialize(**params)
      self.underlying = params[:underlying]
      self.dte = params[:dte]

      @option_type = params[:option_type]
      @time = params[:dte].present? ? params[:dte] / 365.0 : (params[:time] || 0.0)
      @interest = params[:interest] || 0.0
      @sigma = params[:sigma] || 0.0
      @dividend = params[:dividend] || 0.0
      @strike = params[:strike] ? params[:strike].to_f : set_strike_by_delta(params[:delta])

      raise "Unknown option_type" unless KNOWN_OPTION_TYPES.include?(option_type)
    end

    def values
      {
        option_type: option_type,
        underlying: underlying,
        strike: strike,
        sigma: sigma,
        dte: dte,
        time: time,
        interest: interest,
        dividend: dividend,
      }
    end

    def call?
      option_type == :call
    end

    def put?
      option_type == :put
    end

    def dte=(n)
      n = 0 if !n || n < 0
      @time = n / 365.0
      @dte = n
    end

    def underlying=(p)
      @underlying = p.to_f || 0.0
    end

    def delta=(d)
      set_strike_by_delta(d)
    end

    def set_strike_by_delta(delta)
      raise "Delta `#{delta}` should be in range 0..1" unless (0..1).cover?(delta)
      old_strike = @strike.clone
      @strike = @underlying

      i = 0
      loop do
        calced_delta = calc_delta.abs

        if i >= MAX_CYCLES
          diff = (delta.abs - calced_delta.abs).abs
          return @strike if diff <= LAST_TRY_ACCURACY
          raise "Set strike: can't find value for delta #{delta}, limit reached: #{MAX_CYCLES} cycles"
        elsif (delta.abs - calced_delta.abs).abs <= SET_STRIKE_ACCURACY
          @strike = @strike.round(2)
          break
        elsif calced_delta == 0
          raise "Set strike: can't find value for delta #{delta}"
          @strike = old_strike
        else
          @strike = try_next_strike(delta.abs, calced_delta, i)
        end

        i += 1
      end

      @strike
    end

    def calc_price
      raise INVALID_PARAMETERS_MESSAGE unless valid?
      # puts "calcing price with params: price = #{underlying}, strike=#{strike}, time=#{time}, dte=#{dte}, interest=#{interest}, sigma=#{sigma}, dividend=#{dividend} "
      CALC_PRICE_METHODS[option_type].call(underlying, strike, time, interest, sigma, dividend)
    end

    def calc_delta
      raise INVALID_PARAMETERS_MESSAGE unless valid?
      # puts "calcing delta with params: price = #{underlying}, strike=#{strike}, time=#{time}, dte=#{dte}, interest=#{interest}, sigma=#{sigma}, dividend=#{dividend} "
      CALC_DELTA_METHODS[option_type].call(underlying, strike, time, interest, sigma, dividend)
    end

    def calc_gamma
      raise INVALID_PARAMETERS_MESSAGE unless valid?
      Calculator.gamma(underlying, strike, time, interest, sigma, dividend)
    end

    def calc_theta
      raise INVALID_PARAMETERS_MESSAGE unless valid?
      CALC_THETA_METHODS[option_type].call(underlying, strike, time, interest, sigma, dividend)
    end

    def calc_vega
      raise INVALID_PARAMETERS_MESSAGE unless valid?
      Calculator.vega(underlying, strike, time, interest, sigma, dividend)
    end

    def calc_iv(target_option_price)
      raise INVALID_PARAMETERS_MESSAGE unless valid?
      IMPLIED_VOL_METHODS[option_type].call(underlying, strike, time, interest, target_option_price, dividend)
    end

    def calc_greeks
      {
        delta: calc_delta,
        gamma: calc_gamma,
        theta: calc_theta,
        vega: calc_vega,
        iv: sigma * 100,
      }
    end

    private

    def valid?
      underlying > 0 && strike > 0 && sigma >= 0 && time >= 0
    end

    def try_next_strike(delta, calced_delta, i)
      step = 1.0 + PERCENT_STEP_STRIKE + (i / 250)

      if (call? && calced_delta > delta) || (put? && calced_delta < delta)
        strike * step
      else
        strike - step
      end
    end
  end

  class Call < Model
    def initialize(**params)
      params[:option_type] = :call
      super
    end
  end

  class Put < Model
    def initialize(**params)
      params[:option_type] = :put
      super
    end
  end
end
