module Option
  class Model
    KNOWN_OPTION_TYPES = [:call, :put]

    # A map to define methods to call based on option_type
    CALC_PRICE_METHODS  = { call: Calculator.method('price_call'),       put: Calculator.method('price_put') }
    CALC_DELTA_METHODS  = { call: Calculator.method('delta_call'),       put: Calculator.method('delta_put') }
    CALC_THETA_METHODS  = { call: Calculator.method('theta_call'),       put: Calculator.method('theta_put') }
    IMPLIED_VOL_METHODS = { call: Calculator.method('implied_vol_call'), put: Calculator.method('implied_vol_put') }

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

      raise 'Unknown option_type' unless KNOWN_OPTION_TYPES.include?(option_type)
    end

    def call?
      option_type == :call
    end

    def put?
      option_type == :put
    end

    def dte=(n)
      n = 0  if !n || n < 0
      @time = n / 365.0
      @dte = n
    end

    def underlying=(p)
      @underlying = p.to_f || 0.0
    end

    def set_sigma_by_price(price, debug: false)
      raise "Invalid price"  if price.to_i <= 0
      @sigma = 0.5

      loop do
        p = calc_price
        diff = (price - p).abs / price

        if debug
          puts "price = #{p}, sigma = #{@sigma}, diff = #{diff}, but need #{price}, call? = #{call?}"
        end
        break  if diff.round(1) == 0
        
        if call? && p < price
          @sigma += 0.01
        elsif call? && p > price
          @sigma -= 0.01
        elsif put? && p > price
          @sigma -= 0.01
        elsif put? && p < price
          @sigma += 0.01
        end

        # raise "Can't find sigma for #{price}"  if @sigma <= 0 || @sigma >= 10
        break  if @sigma <= 0 || @sigma > 10
      end
      @sigma = @sigma.round(2)
    end

    def set_strike_by_delta(delta)
      raise "Invalid delta"  if delta.to_i <= 0 || delta.to_i > 1
      @strike ||= @underlying

      while delta != (d = calc_delta.abs.round(2))
        raise "Can't find delta for #{delta}"  if d == 0

        if call? && d.round(2) > delta
          @strike *= 1.01
        elsif call? && d.round(2) < delta
          @strike *= 0.99
        elsif put? && d.round(2) > delta
          @strike *= 0.99
        elsif put? && d.round(2) < delta
          @strike *= 1.01
        end
      end
      @strike = @strike.round(2)
    end

    def delta=(d)
      set_strike_by_delta(d)
    end

    def calc_price
      raise "Invalid parameters"  unless valid?
      # puts "calcing price with params: price = #{underlying}, strike=#{strike}, time=#{time}, dte=#{dte}, interest=#{interest}, sigma=#{sigma}, dividend=#{dividend} "
      CALC_PRICE_METHODS[option_type].call(underlying, strike, time, interest, sigma, dividend)
    end

    def calc_delta
      raise "Invalid parameters"  unless valid?
      # puts "calcing delta with params: price = #{underlying}, strike=#{strike}, time=#{time}, dte=#{dte}, interest=#{interest}, sigma=#{sigma}, dividend=#{dividend} "
      CALC_DELTA_METHODS[option_type].call(underlying, strike, time, interest, sigma, dividend)
    end

    def calc_gamma
      raise "Invalid parameters"  unless valid?
      Calculator.gamma(underlying, strike, time, interest, sigma, dividend)
    end

    def calc_theta
      raise "Invalid parameters"  unless valid?
      CALC_THETA_METHODS[option_type].call(underlying, strike, time, interest, sigma, dividend)
    end

    def calc_vega
      raise "Invalid parameters"  unless valid?
      Calculator.vega(underlying, strike, time, interest, sigma, dividend)
    end

    def calc_iv(target_price)
      raise "Invalid parameters"  unless valid?
      IMPLIED_VOL_METHODS[option_type].call(underlying, strike, time, interest, target_price, dividend)
    end

    private

    def valid?
      underlying > 0 && strike > 0 && sigma > 0 && time >= 0
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
