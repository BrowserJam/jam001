abstract Char(String) to String {
	public static function at(string:String, index:Int):Char {
		return cast string.charAt(index);
	}

	public function is_base10_number():Bool {
		return is_in_range('0'.code, '9'.code);
	}

	public function is_identifier():Bool {
		return is_base10_number() || is_letter();
	}

	public function is_in_range(start:Int, end:Int):Bool {
		var char = this.charCodeAt(0);
		return char >= start && char <= end;
	}

	public function is_letter():Bool {
		return is_lower_case_letter() || is_upper_case_letter();
	}

	public function is_lower_case_letter():Bool {
		return is_in_range( 'a'.code, 'z'.code);
	}

	public function is_upper_case_letter():Bool {
		return is_in_range('A'.code, 'Z'.code);
	}

	public function is_whitespace():Bool {
		return this == ' ' || this == '\t' || this == '\r' || this == '\n';
	}
}
