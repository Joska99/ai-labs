import logging
import json
import yfinance as yf
import pandas as pd
from datetime import date

# Setup yfinance cache
yf.set_tz_cache_location("/tmp/yf-cache")

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Helper function to convert pandas objects to JSON-serializable format
def to_json_serializable(obj):
    """
    Convert pandas DataFrames or Series to a JSON-serializable format.
    - DataFrames: Reset index and convert to list of dictionaries with datetimes as ISO strings.
    - Series: Convert to DataFrame, reset index, and convert to list of dictionaries.
    - Other types: Return as is for further processing by default_encoder.
    """
    if isinstance(obj, pd.DataFrame):
        return json.loads(obj.reset_index().to_json(orient='records', date_format='iso'))
    elif isinstance(obj, pd.Series):
        return json.loads(obj.to_frame().reset_index().to_json(orient='records', date_format='iso'))
    return obj  # Non-pandas objects are returned unchanged


# Custom JSON encoder to handle Timestamp and datetime.date objects
def default_encoder(obj):
    """
    Custom encoder for json.dumps to handle non-serializable objects.
    - Converts pandas.Timestamp and datetime.date to ISO format strings.
    """
    if isinstance(obj, pd.Timestamp):
        return obj.isoformat()
    elif isinstance(obj, date):
        return obj.isoformat()
    raise TypeError(
        f"Object of type {type(obj).__name__} is not JSON serializable")


# Fetch stock data with serialization fix
def fetch_stock_data(symbol):
    """
    Fetch stock data for a given symbol using yfinance
    return it in a JSON-serializable format.
    """
    try:
        stock_ticker = yf.Ticker(symbol)
        actual_stock_data = {
            "EARNINGS": to_json_serializable(stock_ticker.get_earnings_history()),
            "EPS": to_json_serializable(stock_ticker.get_eps_trend()),
            # "BV": to_json_serializable(stock_ticker.get_revenue_estimate()),
            # "SALES": to_json_serializable(stock_ticker.get_earnings_history()),
            # "ROE": to_json_serializable(stock_ticker.get_analyst_price_targets()),
            # "ROS": to_json_serializable(stock_ticker.get_analyst_price_targets()),
            # "RateOfReturn": to_json_serializable(stock_ticker.get_analyst_price_targets())
        }
        return actual_stock_data
    except Exception as e:
        logger.error(f"Error fetching stock data for {symbol}: {str(e)}")
        return {"error": str(e)}


# Local testing
if __name__ == "__main__":
    print(fetch_stock_data("LYB"))
