import { Duration, Stack, StackProps } from "aws-cdk-lib";
import * as lambda from "aws-cdk-lib/aws-lambda";
import { Construct } from "constructs";

export class QuickshipStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    new lambda.Function(this, "Rates", {
      functionName: "quickship-rates",
      runtime: lambda.Runtime.NODEJS_24_X,
      architecture: lambda.Architecture.ARM_64,
      handler: "index.handler",
      code: lambda.Code.fromAsset("rates"),
      memorySize: 256,
      timeout: Duration.seconds(10),
      reservedConcurrentExecutions: 2,
      environment: {
        RATES_API_KEY: "FIXTUREVALUE-rates-carrier-key",
      },
    });
  }
}
