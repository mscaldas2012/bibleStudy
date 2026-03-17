from unittest.mock import patch, MagicMock
import pytest
from bible_study.parser import parse
from bible_study.esv_client import get_passage, ESVClientError


def _mock_response(json_data: dict, status_code: int = 200):
    mock = MagicMock()
    mock.status_code = status_code
    mock.json.return_value = json_data
    mock.text = str(json_data)
    return mock


def test_get_passage_success():
    mock_resp = _mock_response({
        "passages": ["For God so loved the world..."],
        "query": "John 3:16",
    })
    with patch("bible_study.esv_client.requests.get", return_value=mock_resp):
        result = get_passage(parse("John 3:16"), api_key="test_key")
    assert result == "For God so loved the world..."


def test_get_passage_no_api_key():
    with patch.dict("os.environ", {}, clear=True):
        # Remove ESV_API_KEY if set
        import os
        os.environ.pop("ESV_API_KEY", None)
        with pytest.raises(ESVClientError, match="API key"):
            get_passage(parse("John 3:16"), api_key=None)


def test_get_passage_401():
    mock_resp = _mock_response({}, status_code=401)
    with patch("bible_study.esv_client.requests.get", return_value=mock_resp):
        with pytest.raises(ESVClientError, match="401"):
            get_passage(parse("John 3:16"), api_key="bad_key")


def test_get_passage_empty_passages():
    mock_resp = _mock_response({"passages": []})
    with patch("bible_study.esv_client.requests.get", return_value=mock_resp):
        with pytest.raises(ESVClientError, match="no passages"):
            get_passage(parse("John 3:16"), api_key="test_key")


def test_network_error():
    import requests as req
    with patch("bible_study.esv_client.requests.get", side_effect=req.RequestException("timeout")):
        with pytest.raises(ESVClientError, match="Network error"):
            get_passage(parse("John 3:16"), api_key="test_key")
