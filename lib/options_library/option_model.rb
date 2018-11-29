module Option
  class Model
    KNOWN_OPTION_TYPES = [:call, :put]

    # A map to define methods to call based on option_type
    CALC_PRICE_METHODS  = { call: Calculator.method('price_call'),       put: Calculator.method('price_put') }
    CALC_DELTA_METHODS  = { call: Calculator.method('delta_call'),       put: Calculator.method('delta_put') }
    CALC_THETA_METHODS  = { call: Calculator.method('theta_call'),       put: Calculator.method('theta_put') }
    IMPLIED_VOL_METHODS = { call: Calculator.method('implied_vol_call'), put: Calculator.method('implied_vol_put') }

    attr_reader :dte
    attr_accessor :option_type, :price, :strike, :time, :interest, :sigma, :dividend

    def initialize(**params)
      @option_type = params[:option_type]
      @price = params[:price].to_f || 0.0
      @strike = params[:strike].to_f || 0.0
      @dte = params[:dte] || 0.0
      @time = params[:dte].present? ? params[:dte] / 365.0 : (params[:time] || 0.0)
      @interest = params[:interest] || 0.0
      @sigma = params[:sigma] || 0.0
      @dividend = params[:dividend] || 0.0
      raise 'Unknown option_type' unless KNOWN_OPTION_TYPES.include?(option_type) 
    end

    def dte=(n)
      n = 0  if n < 0
      self.time = n / 365.0
      @dte = n
    end

    def calc_price
      raise "Invalid parameters"  unless valid?
      CALC_PRICE_METHODS[option_type].call(price, strike, time, interest, sigma, dividend)
    end

    def calc_delta
      raise "Invalid parameters"  unless valid?
      CALC_DELTA_METHODS[option_type].call(price, strike, time, interest, sigma, dividend)
    end

    def calc_gamma
      raise "Invalid parameters"  unless valid?
      Calculator.gamma(price, strike, time, interest, sigma, dividend)
    end

    def calc_theta
      raise "Invalid parameters"  unless valid?
      CALC_THETA_METHODS[option_type].call(price, strike, time, interest, sigma, dividend)
    end

    def calc_vega
      raise "Invalid parameters"  unless valid?
      Calculator.vega(price, strike, time, interest, sigma, dividend)
    end

    def calc_implied_vol(target_price)
      raise "Invalid parameters"  unless valid?
      IMPLIED_VOL_METHODS[option_type].call(price, strike, time, interest, target_price, dividend)
    end

    private

    def valid?
      price > 0 && strike > 0
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
