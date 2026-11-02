# Weather Forecast

This application tells you the weather forecast based on the address provided.

## Description

Given an address, retrieve, cache and display weather forecast data to the user.

## Prerequisites

- Ruby 4.0.8
- Rails 8.4.1

For more details on the installation process check the [Install Ruby on Rails Guide](https://guides.rubyonrails.org/install_ruby_on_rails.html)

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
