using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using Newtonsoft.Json;
using StatusMonitor.Shared.Extensions;

namespace StatusMonitor.Shared.Models.Entities
{
	public class HealthReportDataPoint
	{
		[JsonIgnore]
		[NotMapped]
		public Metrics MetricType
		{
			get
			{
				try
				{
					return Type.ToEnum<Metrics>();
				}
				catch (System.Exception)
				{
					throw new ArgumentException("Invalid MetricType parameter.");
				}
			}
			set
			{
				Type = value.ToString().ToLower();
			}
		}

		public string Type { get; set; }


		[JsonIgnore]
		[NotMapped]
		public AutoLabels MetricLabel
		{
			get
			{
				try
				{
					return Label.ToEnum<AutoLabels>();
				}
				catch (System.Exception)
				{
					throw new ArgumentException("Invalid AutoLabels parameter.");
				}
			}
			set
			{
				Label = value.ToString().ToLower();
			}
		}

		[JsonProperty("Label")]
		public string Label { get; set; }

		public string Source { get; set; }
	}

	public class HealthReport
	{
		public int Health
		{
			get
			{
				return 
					(int)Math.Round(
						(
							(double)(
								Data
								.GroupBy(d => d.MetricLabel)
								.Aggregate(
									0,
									(sum, element) =>
										sum +
										new AutoLabel { Id = element.Key.AsInt() }.DamageUnit() * element.Count()
								)
							)
							/
							(
								Data.Count() * AutoLabel.MaxHealthValue()
							)
						) * 100
					)
				;
			}
			set {
				
			}
		}

		[NotMapped]
		public IEnumerable<HealthReportDataPoint> Data
		{
			get
			{
				return JsonConvert.DeserializeObject<HealthReportDataPoint[]>(HealthData);
			}
			set
			{
				HealthData = JsonConvert.SerializeObject(value);
			}
		}

		[JsonIgnore]
		public string HealthData { get; set; } = JsonConvert.SerializeObject(new List<HealthReportDataPoint>());

		[Key]
		public DateTime Timestamp { get; set; } = DateTime.UtcNow;
	}
}
