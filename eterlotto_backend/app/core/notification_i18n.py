from __future__ import annotations

import json
import os
from datetime import date, datetime
from pathlib import Path
from string import Formatter
from typing import Any, Dict, Optional


class _SafeFormatDict(dict):
    def __missing__(self, key: str) -> str:
        return "{" + key + "}"


class NotificationI18n:
    """Localización dinámica de notificaciones basada en archivos JSON.

    Para añadir un idioma nuevo basta con crear, por ejemplo,
    ``app/locales/notifications/de.json`` con las mismas claves del catálogo
    de fallback. No es necesario modificar la lógica Python.
    """

    def __init__(self, locales_dir: Optional[Path] = None) -> None:
        self.locales_dir = locales_dir or (
            Path(__file__).resolve().parents[1] / "locales" / "notifications"
        )
        self.fallback_locale = self._normalize_locale(
            os.getenv("NOTIFICATION_FALLBACK_LOCALE", "en")
        ) or "en"
        self._catalogs: Dict[str, Dict[str, Any]] = {}

    @staticmethod
    def _normalize_locale(value: Any) -> str:
        text = str(value or "").strip().replace("_", "-").lower()
        return text.split(".", 1)[0]

    def available_locales(self) -> set[str]:
        if not self.locales_dir.exists():
            return set()
        return {
            path.stem.lower()
            for path in self.locales_dir.glob("*.json")
            if path.is_file()
        }

    def resolve_locale(self, requested: Any) -> str:
        normalized = self._normalize_locale(requested)
        available = self.available_locales()
        if normalized in available:
            return normalized
        if "-" in normalized:
            base = normalized.split("-", 1)[0]
            if base in available:
                return base
        if self.fallback_locale in available:
            return self.fallback_locale
        if "en" in available:
            return "en"
        return sorted(available)[0] if available else self.fallback_locale

    def _load(self, locale: str) -> Dict[str, Any]:
        locale = self.resolve_locale(locale)
        if locale in self._catalogs:
            return self._catalogs[locale]

        path = self.locales_dir / f"{locale}.json"
        if not path.exists():
            self._catalogs[locale] = {}
            return self._catalogs[locale]

        with path.open("r", encoding="utf-8") as fh:
            data = json.load(fh)
        self._catalogs[locale] = data if isinstance(data, dict) else {}
        return self._catalogs[locale]

    @staticmethod
    def _get_path(data: Dict[str, Any], dotted_key: str) -> Any:
        current: Any = data
        for part in dotted_key.split("."):
            if not isinstance(current, dict) or part not in current:
                return None
            current = current[part]
        return current

    def _template(self, locale: str, key: str) -> str:
        catalog = self._load(locale)
        value = self._get_path(catalog, key)
        if isinstance(value, str):
            return value

        fallback = self._load(self.fallback_locale)
        value = self._get_path(fallback, key)
        if isinstance(value, str):
            return value
        return key

    def format_date(self, value: Any, locale: str) -> str:
        if value is None:
            return ""
        try:
            dt = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        except (TypeError, ValueError):
            try:
                dt = datetime.combine(date.fromisoformat(str(value)[:10]), datetime.min.time())
            except (TypeError, ValueError):
                return str(value)

        catalog = self._load(locale)
        months = self._get_path(catalog, "date.months")
        if not isinstance(months, list) or len(months) != 12:
            fallback = self._load(self.fallback_locale)
            months = self._get_path(fallback, "date.months")
        if not isinstance(months, list) or len(months) != 12:
            return dt.date().isoformat()

        pattern = self._template(locale, "date.pattern")
        return pattern.format_map(
            _SafeFormatDict(day=dt.day, month=months[dt.month - 1], year=dt.year)
        )

    def format_list(self, values: list[Any], locale: str) -> str:
        items = [str(value) for value in values if str(value).strip()]
        if not items:
            return ""
        if len(items) == 1:
            return items[0]

        catalog = self._load(locale)
        separator = self._get_path(catalog, "list.separator")
        pair_separator = self._get_path(catalog, "list.pair_separator")
        final_separator = self._get_path(catalog, "list.final_separator")

        if not isinstance(separator, str):
            separator = ", "
        if not isinstance(pair_separator, str):
            pair_separator = " and "
        if not isinstance(final_separator, str):
            final_separator = pair_separator

        if len(items) == 2:
            return pair_separator.join(items)
        return separator.join(items[:-1]) + final_separator + items[-1]

    def render(
        self,
        key: Optional[str],
        params: Optional[Dict[str, Any]],
        locale: Any,
        *,
        fallback_text: str = "",
    ) -> str:
        if not key:
            return fallback_text

        resolved = self.resolve_locale(locale)
        values = dict(params or {})

        # Convención: cualquier parámetro llamado date/fecha se localiza aquí.
        for param_name in ("date", "fecha"):
            if param_name in values:
                values[param_name] = self.format_date(values[param_name], resolved)

        # Las listas se formatean con separadores definidos por cada catálogo.
        # Así un idioma nuevo solo necesita su JSON; no requiere modificar Python.
        for param_name, param_value in list(values.items()):
            if isinstance(param_value, (list, tuple)):
                values[param_name] = self.format_list(list(param_value), resolved)

        template = self._template(resolved, key)
        try:
            # Validar placeholders antes de formatear para que errores en un JSON
            # nuevo no rompan el envío de todo el lote.
            list(Formatter().parse(template))
            rendered = template.format_map(_SafeFormatDict(values))
        except Exception:
            rendered = fallback_text or template
        return rendered[:500]

    def title(self, locale: Any) -> str:
        return self.render("push.title", {}, locale, fallback_text="Eterlotto")


notification_i18n = NotificationI18n()
