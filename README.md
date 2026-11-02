# Weather Forecast

This application tells you the weather forecast based on the address provided.

## Description

Given an address, retrieve, cache and display weather forecast data to the user.

## Prerequisites

- Ruby 4.0.8
- Rails 8.4.1

For more details on the installation process check the [Install Ruby on Rails Guide](https://guides.rubyonrails.org/install_ruby_on_rails.html)

## Architecture

This project follows uses the latest Ruby and Ruby on Rails versions and follow the latest community conventions.
Below are listed some of these conventions, as well as other architectural decisions:

- Forecasts are grouped by the `Address` model, which has a one-to-one relationship with postal code
- Both `Address` and `WeatherDatum` are stored in the DB to avoid extra lookups in external APIs
- `addresses.postal_code` has an index to increase lookup speed in the databse
- SQLite as primary read-write database and cache store
- RESTful endpoints, such as `/addresses` and `/weather_data`
- Avoid using external libraries for simplicity (use of `Net::HTTP` instead of `HTTParty` or `Faraday`
- API keys stored in credentials file for security
- Use of Turbo Frames to display weather forecast in the Address page
- Use of native Rails cache solution
- `WeatherData` is cached but database records are created each time data is pulled from the API
- Logging and handling errors for troubleshooting and displaying useful error messages to the user

## Future improvements

Due to time constraints, some requirements, such as the functional ones, had to be prioritized. Here are some concerns to be taken into consideration as next steps:

- Display future weather forecast to the user, not prioritized due to API billing costs
- Allow the user to search addresses outside the US
- Handle multiple address lookup and weather forecast APIs to increase project availability
- Add an abstraction layer for the `Address` and `WeatherData` models to adapt the core domain models to any third party providers
- Visual improvements such as styling and displaying loading indicators to the user
- Automated tests to catch development errors before the project reaches the users
- Consider creating service objects to encapsulate logic such as thirs-party API connections

## Installation and Setup

1. Clone the repository:

```bash
$ git clone https://github.com/eduardoyutaka/weather_forecast.git
```

2. Navigate to the project directory:

```bash
$ cd weather_forecast
```

3. Install dependencies:

```bash
$ bundle install
```

4. Run migrations:

```bash
$ bin/rails db:migrate
```

5. Create a `config/master.key` file:

```bash
$ echo "09fee242a17a0fb1e950d42b596e2dd5" > config/master.key
```

Note: this project is **not ready for production** as the `master.key` is shared in plain text

6. Start the application:

```bash
$ bin/dev
```

## Running Tests

```bash
$ bin/rails test
```
