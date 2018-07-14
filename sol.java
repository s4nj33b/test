
import java.util.*;
class sol {

  public static long calculateTax( String name , long salary){
    double incomeTax=0;
    if (salary >= 300000) {
      incomeTax = (double)salary * 0.2;
    }
    else if (salary>=100000 && salary <= 300000) {
      incomeTax = (double)salary * 0.1;
    }

    System.out.println(name+" : ₹"+(long)incomeTax);
    return 0;
}


  public static void main(String[] args) {
    System.out.println("Tax Calculator App");
    System.out.println("----- WELCOME ----- ");
    Scanner sc = new Scanner(System.in);
    int totalPersons;
    System.out.println("Enter total person count: ");
    totalPersons =  sc.nextInt();
    String[] name = new String[totalPersons];
    long[] salary = new long[totalPersons];
    // Input the data into arrays
    for (int i =0; i<totalPersons;i++) {
      System.out.println("\nEnter name "+(i+1)+":");
      name[i] = sc.next();
      System.out.println("\nEnter "+ name[i]+"\'s Annual Income: ");
      salary[i] = sc.nextLong();
    }
    System.out.println("\n\nNames with liable taxes");
    System.out.println("—————————————-----------");
    for (int i =0; i<totalPersons;i++) {
      calculateTax(name[i], salary[i]);

    }

  }
}
