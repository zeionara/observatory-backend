import StORM
import MongoDBStORM
import Foundation

class Experiment: MongoDBStORM {
	var id					: String = ""
	var isCompleted			: Bool = false
	var startTimestamp		: Double = NSDate().timeIntervalSince1970
    var completionTimestamp	: Double = NSDate().timeIntervalSince1970
	var progress			: Float = 0.0
	var metrics				: [String: Float] = [String: Float]()
	var params				: [String: Any] = [String: Any]()

	var startedAt: NSDate {
		NSDate(timeIntervalSince1970: startTimestamp)
	}

	var completedAt: NSDate {
		NSDate(timeIntervalSince1970: completionTimestamp)
	}

	// The name of the database table
	override init() {
		super.init()
		_collection = EXPERIMENTS_COLLECTION_NAME
	}


	// The mapping that translates the database info back to the object
	// This is where you would do any validation or transformation as needed
	override func to(_ this: StORMRow) {
		id				= this.data["_id"] as? String					??	""
        isCompleted		= this.data["isCompleted"] as? Bool				??	false
		startTimestamp	= this.data["startTimestamp"] as? Double		??	NSDate().timeIntervalSince1970
		startTimestamp	= this.data["completionTimestamp"] as? Double	??	NSDate().timeIntervalSince1970
		progress		= Float(this.data["progress"] as? Double				??	0.0)
		metrics 		= (this.data["metrics"] as? [String: Any])?.map{(key, value) in
			(key, Float(value as! Double))
		}.reduce([:]) {
            var dict: [String: Float] = $0!
            dict[$1.0] = $1.1   
            return dict
		} ?? [String: Float]()
		params	 		= this.data["params"] as? [String: Any]			?? [String: Any]()
	}

	// A simple iteration.
	// Unfortunately necessary due to Swift's introspection limitations
	func rows() -> [Experiment] {
		var rows = [Experiment]()
		for i in 0..<self.results.rows.count {
			let row = Experiment()
			row.to(self.results.rows[i])
			rows.append(row)
		}
		return rows
	}
}
