module Option
  class Calculator
    class << self
      # used for finding implied vol based on a market (target) price
      LOW_VOL, HIGH_VOL, VOL_TOLERANCE = 0.0, 5.0, 0.0001

      # less than this value almost equals to zero
      TIME_THRESHOLD = 0.00001

      # used for min/max normal distribution
      MIN_Z_SCORE, MAX_Z_SCORE = -7.98, +7.98

      include Math

      # computes the call price sensitivity to a change in underlying price
      def delta_call(underlying, strike, time, interest, sigma, dividend)
        return 0.5 if underlying == strike and time <= TIME_THRESHOLD
        norm_sdist(d_one(underlying, strike, time, interest, sigma, dividend))
      end

      # computes the put price sensitivity to a change in underlying price
      def delta_put(underlying, strike, time, interest, sigma, dividend)
        return 0.5 if underlying == strike and time <= TIME_THRESHOLD
        delta_call(underlying, strike, time, interest, sigma, dividend) - 1
      end

      # computes the option price sensitivity to a change in delta
      def gamma(underlying, strike, time, interest, sigma, dividend)
        return 0 if underlying == strike && time <= TIME_THRESHOLD

        g = phi(d_one(underlying, strike, time, interest, sigma, dividend)) / (underlying * sigma * sqrt(time))
        g.nan? ? 0 : g
      end

      # computes the call price sensitivity to a change in time
      def theta_call(underlying, strike, time, interest, sigma, dividend)
        return 0 if time == 0

        term1 = underlying * phi(d_one(underlying, strike, time, interest, sigma, dividend)) * sigma / (2 * sqrt(time))

        term2 = interest * strike * exp(-1.0 * interest * time) * norm_sdist(d_two(underlying, strike, time, interest, sigma, dividend))
        result = (-term1 - term2) / 365.0
        result.nan? ? 0 : result
      end

      # computes the put price sensitivity to a change in time
      def theta_put(underlying, strike, time, interest, sigma, dividend)
        return 0 if time == 0

        term1 = underlying * phi(d_one(underlying, strike, time, interest, sigma, dividend)) * sigma / (2 * sqrt(time))

        term2 = interest * strike * exp(-1.0 * interest * time) * norm_sdist(-d_two(underlying, strike, time, interest, sigma, dividend))
        result = (-term1 + term2) / 365.0
        result.nan? ? 0 : result
      end

      # computes the option price sensitivity to a change in volatility
      def vega(underlying, strike, time, interest, sigma, dividend)
        0.01 * underlying * sqrt(time) * phi(d_one(underlying, strike, time, interest, sigma, dividend))
      end

      # computes the fair value of the call based on the knowns and assumed volatility (sigma)
      def price_call(underlying, strike, time, interest, sigma, dividend)
        return 0 if underlying == strike && time <= TIME_THRESHOLD

        d1 = d_one(underlying, strike, time, interest, sigma, dividend)
        discounted_underlying = exp(-1.0 * dividend * time) * underlying

        probability_weighted_value_of_being_exercised = discounted_underlying * norm_sdist(d1)

        d2 = d1 - (sigma * sqrt(time))
        discounted_strike = exp(-1.0 * interest * time) * strike
        probability_weighted_value_of_discounted_strike = discounted_strike * norm_sdist(d2)

        expected_value = probability_weighted_value_of_being_exercised - probability_weighted_value_of_discounted_strike
      end

      # computes the fair value of the put based on the knowns and assumed volatility (sigma)
      def price_put(underlying, strike, time, interest, sigma, dividend)
        return 0 if underlying == strike && time <= TIME_THRESHOLD

        d2 = d_two(underlying, strike, time, interest, sigma, dividend)
        discounted_strike = strike * exp(-1.0 * interest * time)

        probabiltity_weighted_value_of_discounted_strike = discounted_strike * norm_sdist(-1.0 * d2)

        d1 = d2 + (sigma * sqrt(time))
        discounted_underlying = underlying * exp(-1.0 * dividend * time)
        probability_weighted_value_of_being_exercised = discounted_underlying * norm_sdist(-1.0 * d1)

        expected_value = probabiltity_weighted_value_of_discounted_strike - probability_weighted_value_of_being_exercised
      end

      # finds the implied volatility based on the target_price passed in.
      def implied_vol_call(underlying, strike, time, interest, target_price, dividend)
        low, high = LOW_VOL, HIGH_VOL

        while (high - low > VOL_TOLERANCE)
          if (price_call(underlying, strike, time, interest, (high + low) / 2.0, dividend) > target_price)
            high = (high + low) / 2.0
          else
            low = (high + low) / 2.0
          end
        end

        (high + low) / 2.0
      end

      # finds the implied volatility based on the target_price passed in.
      def implied_vol_put(underlying, strike, time, interest, target_price, dividend)
        low, high = LOW_VOL, HIGH_VOL

        while (high - low > VOL_TOLERANCE)
          if (price_put(underlying, strike, time, interest, (high + low) / 2.0, dividend) > target_price)
            high = (high + low) / 2.0
          else
            low = (high + low) / 2.0
          end
        end

        (high + low) / 2.0
      end

      # probability of being exercised at maturity (must be greater than d2 by (sigma*sqrt(time)) if exercised)
      def d_one(underlying, strike, time, interest, sigma, dividend)
        return 0 if underlying == strike and time < TIME_THRESHOLD

        numerator = (log(underlying / strike) + (interest - dividend + 0.5 * sigma ** 2.0) * time)
        denominator = (sigma * sqrt(time))
        numerator / denominator
      end

      # probability of underlying reaching the strike price (must be smaller than d1 by (sigma*sqrt(time)) if exercised.
      def d_two(underlying, strike, time, interest, sigma, dividend)
        d_one(underlying, strike, time, interest, sigma, dividend) - (sigma * sqrt(time))
      end

      # Normal Standard Distribution
      # using Taylor's approximation
      def norm_sdist(z)
        return 0.0 if z <= MIN_Z_SCORE
        return 1.0 if z >= MAX_Z_SCORE
        raise "norm_sdist: Z is not a number" if z.to_f.nan?

        i, sum, term = 3.0, 0.0, z

        while (sum + term != sum)
          sum = sum + term
          term = term * z * z / i
          i += 2.0

          if i >= 1000
            puts "Returning emergency: i > 1000"
            z = z > 0 ? 1.0 : 0.0
            break
          end
        end

        0.5 + sum * phi(z)
      end

      # Standard Gaussian pdf
      def phi(x)
        numerator = exp(-1.0 * x * x / 2.0)
        denominator = sqrt(2.0 * PI)
        numerator / denominator
      end
    end
  end
end
