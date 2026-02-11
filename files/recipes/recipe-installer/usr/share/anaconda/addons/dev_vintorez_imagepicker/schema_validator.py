import re
import types
from typing import Any, Callable, Pattern, Union, get_args, get_origin


class ValidatableType:
	"""
	Base class for custom validators
	"""
	def validate(self, value: Any, path: str, validate_callback: Callable[[Any, Any, str], None]) -> None:
		raise NotImplementedError

	def __or__(self, other):
		return Or(self, other)

	def __ror__(self, other):
		return Or(other, self)

class String(ValidatableType):
	def __init__(self, min_len: int = 0, max_len: int | None = None, regex: str | None = None):
		self.min_len = min_len
		self.max_len = max_len
		self.regex: Pattern | None = re.compile(regex) if regex else None

	def validate(self, value: Any, path: str, validate_callback: Callable) -> None:
		if not isinstance(value, str):
			raise ValueError(f"Invalid Data @ {path}: Expected str, got {type(value).__name__}")
		if len(value) < self.min_len:
			raise ValueError(f"Invalid Data @ {path}: String length {len(value)} < min {self.min_len}")
		if self.max_len is not None and len(value) > self.max_len:
			raise ValueError(f"Invalid Data @ {path}: String length {len(value)} > max {self.max_len}")
		if self.regex and not self.regex.match(value):
			raise ValueError(f"Invalid Data @ {path}: String '{value}' does not match regex '{self.regex.pattern}'")

class Number(ValidatableType):
	def __init__(self, min_val: float | None = None, max_val: float | None = None):
		self.min_val = min_val
		self.max_val = max_val

	def validate(self, value: Any, path: str, validate_callback: Callable) -> None:
		if not isinstance(value, (int, float)):
			raise ValueError(f"Invalid Data @ {path}: Expected int or float, got {type(value).__name__}")
		if self.min_val is not None and value < self.min_val:
			raise ValueError(f"Invalid Data @ {path}: Number {value} < min {self.min_val}")
		if self.max_val is not None and value > self.max_val:
			raise ValueError(f"Invalid Data @ {path}: Number {value} > max {self.max_val}")

class List(ValidatableType):
	def __init__(self, item_type: Any, min_items: int = 0, max_items: int | None = None):
		self.item_type = item_type
		self.min_items = min_items
		self.max_items = max_items

	def validate(self, value: Any, path: str, validate_callback: Callable) -> None:
		if not isinstance(value, list):
			raise ValueError(f"Invalid Data @ {path}: Expected list, got {type(value).__name__}")
		if len(value) < self.min_items:
			raise ValueError(f"Invalid Data @ {path}: List length {len(value)} < min {self.min_items}")
		if self.max_items is not None and len(value) > self.max_items:
			raise ValueError(f"Invalid Data @ {path}: List length {len(value)} > max {self.max_items}")

		for i, item in enumerate(value):
			validate_callback(item, self.item_type, f"{path}[{i}]")

class Optional(ValidatableType):
	def __init__(self, inner_type: Any):
		self.inner_type = inner_type

	def validate(self, value: Any, path: str, validate_callback: Callable) -> None:
		if value is None:
			return
		validate_callback(value, self.inner_type, path)

class Or(ValidatableType):
	def __init__(self, *options):
		flat_options = []
		for option in options:
			if isinstance(option, Or):
				flat_options.extend(option.options)
			else:
				flat_options.append(option)
		self.options = tuple(flat_options)

	def validate(self, value: Any, path: str, validate_callback: Callable) -> None:
		errors = set()
		for opt in self.options:
			try:
				validate_callback(value, opt, path)
				return
			except ValueError as e:
				errors.add(str(e))

		raise ValueError(f"Invalid Data @ {path}: Value {value} does not match any types in the union.\nDetails:\n  - " + "\n  - ".join(errors))


class Schema:
	def __init__(self, schema: Any):
		"""
		Initialize with a schema

		schema can be:
			- A type: str, int, float, dict, list
			- A generic alias: list[int], dict[str, Any]
			- A single type list: [str], [float]
			- An untyped dict: {"id": str, "list": [str]}
			- A TypedDict class
			- A Schema class
		"""
		self._validate_schema(schema)
		self.schema = schema

	def validate(self, data: Any) -> Any:
		self._validate_recursive(data, self.schema, "root")
		return data

	def _validate_schema(self, schema: Any):
		if isinstance(schema, Schema):
			return

		if isinstance(schema, ValidatableType):
			if isinstance(schema, List):
				self._validate_schema(schema.item_type)
			if isinstance(schema, Optional):
				self._validate_schema(schema.inner_type)
			if isinstance(schema, Or):
				for opt in schema.options:
					self._validate_schema(opt)
			return

		if schema is Any:
			return

		origin = get_origin(schema)
		if origin is not None:
			args = get_args(schema)
			for arg in args:
				if arg is not type(None):
					self._validate_schema(arg)
			return

		if isinstance(schema, list):
			if len(schema) != 1:
				raise ValueError(f"Invalid Schema: List definition must have exactly 1 item (e.g. [str]), got {len(schema)}.")
			self._validate_schema(schema[0])
			return

		if isinstance(schema, dict):
			for k, v in schema.items():
				if not isinstance(k, str):
					raise ValueError(f"Invalid Schema: Dict keys must be strings, got {k}.")
				self._validate_schema(v)
			return

		if isinstance(schema, type):
			return

		raise ValueError(f"Invalid Schema: {schema} is not a valid type or validator.")

	def _validate_recursive(self, data: Any, schema: Any, path: str):
		if isinstance(schema, ValidatableType):
			schema.validate(data, path, self._validate_recursive)
			return

		if isinstance(schema, Schema):
			self._validate_recursive(data, schema.schema, path)
			return

		origin = get_origin(schema)
		if origin is not None:
			args = get_args(schema)

			if origin is Union or origin is types.UnionType:
				for arg in args:
					try:
						self._validate_recursive(data, arg, path)
						return
					except ValueError:
						continue
				raise ValueError(f"Invalid Data @ {path}: {data} does not match any of {args} in the union.")

			if origin is list:
				if not isinstance(data, list):
					raise ValueError(f"Invalid Data @ {path}: Expected list, got {type(data).__name__}")
				if args:
					for i, item in enumerate(data):
						self._validate_recursive(item, args[0], f"{path}[{i}]")
				return

			if origin is dict:
				if not isinstance(data, dict):
					raise ValueError(f"Invalid Data @ {path}: Expected dict, got {type(data).__name__}")
				if args:
					k_type, v_type = args
					for k, v in data.items():
						self._validate_recursive(k, k_type, f"{path} (key)")
						self._validate_recursive(v, v_type, f"{path}[{k}]")
				return

		if isinstance(schema, list):
			if not isinstance(data, list):
				raise ValueError(f"Invalid Data @ {path}: Expected list, got {type(data).__name__}")
			if len(schema) == 1:
				for i, item in enumerate(data):
					self._validate_recursive(item, schema[0], f"{path}[{i}]")
			return

		if isinstance(schema, dict):
			if not isinstance(data, dict):
				raise ValueError(f"Invalid Data @ {path}: Expected dict, got {type(data).__name__}")

			for key, sub_schema in schema.items():
				is_opt = isinstance(sub_schema, Optional)
				if key not in data:
					if is_opt:
						continue
					raise ValueError(f"Invalid Data @ {path}: Missing required key '{key}'")
				self._validate_recursive(data[key], sub_schema, f"{path}.{key}")
			return

		if isinstance(schema, type):
			if schema is Any:
				return
			if not isinstance(data, schema):
				raise ValueError(f"Invalid Data @ {path}: Expected {schema.__name__}, got {type(data).__name__}")
			return
