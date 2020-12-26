import StORM
import MongoDBStORM
import Foundation

class User: MongoDBStORM {
	var id				: String = ""
	var login			: String = ""
	var password		: String = ""

	// The name of the database table
	override init() {
		super.init()
		_collection = USERS_COLLECTION_NAME
	}

	// The mapping that translates the database info back to the object
	// This is where you would do any validation or transformation as needed
	override func to(_ this: StORMRow) {
		id				= this.data["_id"] as? String					??	""
        login			= this.data["login"] as? String					??	""
        password		= this.data["password"] as? String				??	""
	}

	// A simple iteration.
	// Unfortunately necessary due to Swift's introspection limitations
	func rows() -> [User] {
		var rows = [User]()
		for i in 0..<self.results.rows.count {
			let row = User()
			row.to(self.results.rows[i])
			rows.append(row)
		}
		return rows
	}
}
